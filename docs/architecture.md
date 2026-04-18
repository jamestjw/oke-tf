# Architecture

## Goals

- Use OCI Free Tier carefully while keeping the design production-shaped.
- Keep the OKE API endpoint private.
- Start with one Ampere worker node and scale later without redesign.
- Use `ingress-nginx` behind an OCI Network Load Balancer.
- Bootstrap Argo CD from inside the VCN, then move to GitOps.

## High-Level Topology

```text
Admin Workstation
  |
  | terraform apply (infra only)
  v
OCI
  |
  +-- VCN
      +-- Private OKE endpoint subnet
      +-- Private worker subnet
      +-- Private pod subnet
      +-- Load balancer subnet
      +-- NAT gateway
      +-- Service gateway
      +-- Route tables
      +-- NSGs
      +-- OCI Bastion access path
  |
  +-- OKE Cluster
      +-- Private API endpoint
      +-- 1 x Ampere worker node
      +-- VCN-native pod networking
  |
  +-- In-VCN bootstrap runner or bastion-connected session
      +-- terraform apply (platform bootstrap)
          +-- ingress-nginx
          +-- argocd
```

## Core Principle

Do not try to make a single Terraform run perform both OCI provisioning and private-cluster bootstrap from a public workstation.

Instead:

1. Provision OCI infrastructure and OKE first.
2. Use a trusted execution point inside the VCN.
3. Bootstrap the cluster from there.
4. Hand off ongoing cluster management to Argo CD.

## Stack Boundaries

### 1. `stacks/infra-free-tier`

Purpose:

- Own all OCI resources.
- Never require direct Kubernetes API access.

Contents:

- VCN and subnets
- gateways and route tables
- NSGs
- OKE cluster
- OKE node pool
- optional Bastion resources
- outputs required for private bootstrap

Modules used:

- `modules/network`
- `modules/oke`
- `modules/bastion`

### 2. `stacks/platform-bootstrap`

Purpose:

- Own only initial in-cluster platform components.
- Run from inside the VCN or through a stable private access path.

Contents:

- `helm_release` for `ingress-nginx`
- `helm_release` for `argo-cd`
- optional namespaces and baseline manifests

Providers used:

- `kubernetes`
- `helm`

This stack must not be run from a machine that cannot reach the private OKE API endpoint.

## Networking Model

### Subnets

`oke_endpoint_subnet`
- Private subnet for the control plane endpoint path.
- No public exposure.

`worker_subnet`
- Private subnet for worker nodes.
- Nodes should not receive public IPs.

`pod_subnet`
- Private subnet for VCN-native pod IP allocation.
- Keeps pod addressing separate and easier to reason about.

`lb_subnet`
- Subnet for OCI load balancer resources.
- If using a public-facing NLB, this subnet is the public entry point.

### Gateways

`NAT Gateway`
- Worker and pod egress for updates, image pulls, and outbound access.

`Service Gateway`
- Access to OCI services without traversing the public internet where supported.

`Internet Gateway`
- Required only if the load balancer frontend is public.

### Security Model

Prefer NSGs over broad security lists.

Recommended NSGs:

- `nsg-oke-endpoint`
- `nsg-workers`
- `nsg-loadbalancer`
- `nsg-bastion-access` if needed for supporting resources

Keep rules narrow:

- Admin path to private API endpoint only
- Control plane to workers per OKE requirements
- NLB ingress on `80` and `443`
- NLB to ingress-nginx backends
- Worker egress through NAT

## OKE Design

Cluster settings:

- Private endpoint enabled
- Public endpoint disabled
- VCN-native pod networking
- dedicated endpoint subnet

Node pool settings:

- shape: `VM.Standard.A1.Flex`
- node count: `1`
- OCPUs: `1`
- memory: `6 GB`

This is intentionally small and not highly available, but the network and module structure should support a later move to `2` or `3` nodes without rework.

## Bastion And Access Strategy

OCI Bastion is used as the secure operator access path, but not as the only long-term automation strategy.

Professional posture:

1. Bastion for operator access and break-glass administration.
2. Private runner or management host in the VCN for repeatable bootstrap and automation.

Why:

- Bastion is good for controlled access.
- Long-running Terraform and Helm applies are more reliable from an execution environment already inside the VCN.
- This avoids coupling successful applies to ad hoc operator tunnels.

## Bootstrap Strategy

After `infra-free-tier` completes:

1. Start a private execution session.
2. Generate or obtain kubeconfig for the private endpoint.
3. Run `platform-bootstrap` from that private environment.
4. Install `ingress-nginx`.
5. Install `argocd`.
6. Register Argo CD against the Git repository containing platform and application manifests.

After that point:

- Terraform should continue to own OCI infrastructure.
- Argo CD should own most in-cluster declarative resources.

This prevents Terraform from becoming the long-term deployment engine for routine Kubernetes workloads.

## Ingress Design

Use `ingress-nginx` as the cluster L7 entry point.

Recommended model:

- `ingress-nginx` exposed by a `Service` of type `LoadBalancer`
- OCI cloud integration provisions an OCI Network Load Balancer when the correct service annotations are used
- NLB handles L4 exposure
- NGINX handles HTTP and HTTPS ingress routing

This is a clean division of responsibility:

- OCI NLB: external transport entry point
- NGINX ingress: Kubernetes-native routing layer

## State Strategy

Use remote state from the start.

Recommended:

- OCI Object Storage backend
- separate state locations for `infra-free-tier` and `platform-bootstrap`

This keeps stack state isolated and reduces accidental coupling between OCI resources and in-cluster bootstrap state.

## Naming And Tags

Use consistent names:

- `${project}-${environment}-${resource}`

Example:

- `oracle-oke-free-vcn`
- `oracle-oke-free-cluster`
- `oracle-oke-free-workers`

Common tags:

- `project = oracle-oke`
- `environment = free-tier`
- `managed-by = terraform`
- `layer = infra` or `layer = platform-bootstrap`

## Suggested Module Contracts

### `modules/network`

Inputs:

- compartment OCID
- VCN CIDR
- endpoint subnet CIDR
- worker subnet CIDR
- pod subnet CIDR
- lb subnet CIDR
- tags

Outputs:

- VCN OCID
- subnet OCIDs
- NSG OCIDs
- route table OCIDs if needed downstream

### `modules/oke`

Inputs:

- compartment OCID
- cluster name
- Kubernetes version
- VCN OCID
- endpoint subnet OCID
- worker subnet OCID
- pod subnet OCID
- worker NSG OCID
- endpoint NSG OCID
- node shape
- node count
- node OCPUs
- node memory in GB
- SSH public key if enabled
- tags

Outputs:

- cluster OCID
- node pool OCID
- cluster private endpoint
- kubeconfig generation command hints

### `modules/bastion`

Inputs:

- compartment OCID
- VCN OCID or target subnet
- tags

Outputs:

- bastion OCID
- session creation hints

## Apply Workflow

### Phase 1: OCI Infrastructure

Run from your normal workstation:

1. `terraform init` in `stacks/infra-free-tier`
2. `terraform plan`
3. `terraform apply`

Result:

- network exists
- OKE exists
- private endpoint exists
- worker node exists
- access path exists

### Phase 2: Private Bootstrap

Run from a host that can reach the private endpoint:

1. obtain kubeconfig
2. verify `kubectl get nodes`
3. `terraform init` in `stacks/platform-bootstrap`
4. `terraform plan`
5. `terraform apply`

Result:

- `ingress-nginx` installed
- `argocd` installed

### Phase 3: GitOps Handoff

1. create Argo CD root application
2. point Argo CD at your manifests repository structure
3. let Argo CD reconcile platform add-ons and workloads

## What Not To Do

- Do not put OCI infra and Helm bootstrap in the same Terraform state.
- Do not depend on a one-off local tunnel as the permanent automation mechanism.
- Do not expose the OKE API publicly just to simplify bootstrap.
- Do not make worker nodes public.
- Do not let Terraform remain the primary day-2 deployment engine for normal Kubernetes apps once Argo CD is in place.

## Sensible Next Build Step

Implement the repository in this order:

1. `modules/network`
2. `modules/oke`
3. `modules/bastion`
4. `stacks/infra-free-tier`
5. `stacks/platform-bootstrap`

That gets the hardest architectural decisions right early and keeps the repository clean as it grows.
