# oracle-tf

Terraform layout for a small OCI OKE platform on Free Tier. The cluster may be
small, but we try our best to follow best practices to have a professional setup.

## Design

- Private OKE API endpoint
- `BASIC_CLUSTER` to avoid enhanced OKE control plane charges
- `VM.Standard.A1.Flex` with `1` OCPU and `6` GB RAM, 1 node only for now
- `ingress-nginx` exposed through an OCI Network Load Balancer to expose
services
- Argo CD bootstrapped from inside the VCN after cluster creation

## Prerequisites

- Install Terraform: <https://developer.hashicorp.com/terraform/install>
- Install the OCI CLI: <https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm>
- Authenticate the OCI CLI locally before running the Terraform stacks, Bastion helper, or kubeconfig generation steps.

## Stack Strategy

This repository is split into two Terraform stacks plus a bootstrap path:

1. `stacks/infra-free-tier`
   Creates OCI infrastructure only: networking, bastion access path, and OKE.
2. `stacks/platform-bootstrap`
   Runs from inside the VCN and installs in-cluster platform components like `ingress-nginx` and `argocd`.
3. Argo CD then manages the rest of the cluster from Git.

This separation is intentional. It keeps OCI infrastructure lifecycle independent from Kubernetes API reachability.

## Repository Layout

```text
oracle-tf/
  README.md
  docs/
    architecture.md
  modules/
    network/
    oke/
    bastion/
  stacks/
    infra-free-tier/
      backend.tf
      providers.tf
      versions.tf
      locals.tf
      main.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
    platform-bootstrap/
      backend.tf
      providers.tf
      versions.tf
      main.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
```

## Execution Model

1. Run `stacks/infra-free-tier` from your normal workstation.
2. Establish private connectivity through OCI Bastion or run from a management runner inside the VCN.
3. Run `stacks/platform-bootstrap` from that private execution environment.
4. Let Argo CD take ownership of application and add-on manifests after bootstrap.

## Remote State

Both stacks are configured for partial backend configuration:

```hcl
terraform {
  backend "s3" {}
}
```

Use OCI Object Storage through Terraform's S3-compatible backend.

If you do not want to store Terraform state in OCI Object Storage yet, you can keep state local instead. In that case:

- do not create `backend.hcl`
- run `terraform init` without `-backend-config=backend.hcl`
- keep the generated local state files on your workstation

### 1. Get your Object Storage namespace

```bash
oci os ns get
```

### 2. Create a bucket

Example:

```bash
oci os bucket create \
  --namespace-name "<namespace>" \
  --compartment-id "<compartment-ocid>" \
  --name "oracle-tf-state"
```

### 3. Create local backend config files

Duplicate the example variable files:

```bash
cp stacks/infra-free-tier/backend.hcl.example stacks/infra-free-tier/backend.hcl
cp stacks/platform-bootstrap/backend.hcl.example stacks/platform-bootstrap/backend.hcl
```

Then replace:

- bucket name
- region
- Object Storage namespace in the endpoint URL

The stacks intentionally use different state keys:

- `infra-free-tier/terraform.tfstate`
- `platform-bootstrap/terraform.tfstate`

### 4. Create local Terraform variable files

Copy the committed example files and customize them for your tenancy, compartment, and cluster settings:

```bash
cp stacks/infra-free-tier/terraform.tfvars.example stacks/infra-free-tier/terraform.tfvars
cp stacks/platform-bootstrap/terraform.tfvars.example stacks/platform-bootstrap/terraform.tfvars
```

You should review and update the values in:

- `stacks/infra-free-tier/terraform.tfvars`
- `stacks/platform-bootstrap/terraform.tfvars`

### Notes

- The bucket must already exist before `terraform init`.
- OCI Object Storage does not provide DynamoDB-style state locking for the S3 backend, so avoid concurrent applies.
- The `scripts/tf.sh` wrapper sets the AWS SDK checksum environment variables required for OCI Object Storage compatibility.

## Infra Provisioning

After configuring `stacks/infra-free-tier/backend.hcl` and `stacks/infra-free-tier/terraform.tfvars`, create the OCI networking, Bastion, and OKE cluster from your normal workstation:

```bash
cd stacks/infra-free-tier
../../scripts/tf.sh init -backend-config=backend.hcl
# If you want to keep state local instead, use: ../../scripts/tf.sh init
../../scripts/tf.sh plan
../../scripts/tf.sh apply
```

Once apply completes, continue with the Bastion workflow below to reach the private OKE API.

## OKE Kubernetes Version Upgrade

The Kubernetes version for the OKE control plane and node pool is managed from `stacks/infra-free-tier/terraform.tfvars`:

```hcl
kubernetes_version = "v1.35.2"
```

Before upgrading, confirm the target version is available for OKE in the configured OCI region.

Run the upgrade from the infra stack:

```bash
cd stacks/infra-free-tier
../../scripts/tf.sh plan
```

Upgrade the control plane first:

```bash
../../scripts/tf.sh apply -target=module.oke.oci_containerengine_cluster.this
```

Then update the node pool version in Terraform:

```bash
../../scripts/tf.sh apply -target=module.oke.oci_containerengine_node_pool.this
```

After the node pool version has been updated, manually cycle the node from the OCI Console:

```text
OCI Console
-> Kubernetes Clusters
-> oracle-oke-free
-> Node pools
-> worker node pool
-> Cycle nodes
```

Individual worker nodes are not managed as separate Terraform resources in this repository. Terraform manages the OKE node pool, and OCI manages the compute instances behind that node pool.

Do not cycle nodes before Terraform updates the node pool version. Otherwise, OCI may recreate a node on the old Kubernetes version.

With `node_count = 1`, cycling the node can cause workload downtime unless the workloads tolerate losing the only worker node.

Verify the replacement node through the Bastion tunnel:

```bash
export KUBECONFIG="$HOME/.kube/oracle-oke-free.yaml"
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl version
```

Avoid concurrent applies. OCI Object Storage does not provide DynamoDB-style state locking for the S3 backend.

## Bastion Access

Use OCI Bastion port forwarding to reach the private OKE API from your
workstation.

### 1. Open the local tunnel

Use the helper script in `scripts/open-oke-api-tunnel.sh`.

By default it fetches these values from `stacks/infra-free-tier` Terraform outputs:

- `bastion_id`
- `oke_private_endpoint`

It will:

1. create an OCI Bastion port-forward session if `BASTION_SESSION_ID` is not already set
2. wait for the session to become `ACTIVE`
3. create a dedicated kubeconfig for the cluster
4. point that kubeconfig at the local tunnel
5. open the SSH tunnel to the private OKE API endpoint

Example:

```bash
chmod +x scripts/open-oke-api-tunnel.sh

SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519" \
LOCAL_PORT=16443 \
OCI_REGION="ca-montreal-1" \
./scripts/open-oke-api-tunnel.sh
```

By default the script writes a dedicated kubeconfig to:

```bash
$HOME/.kube/oracle-oke-free.yaml
```

You can override that path:

```bash
KUBECONFIG_PATH="$HOME/.kube/my-oke.yaml" ./scripts/open-oke-api-tunnel.sh
```

If you want to override the Terraform stack path:

```bash
TF_STACK_DIR="$PWD/stacks/infra-free-tier" ./scripts/open-oke-api-tunnel.sh
```

If you already created a Bastion session and want to reuse it:

```bash
BASTION_SESSION_ID="<bastion-session-ocid>" ./scripts/open-oke-api-tunnel.sh
```

Keep that terminal open while using `kubectl`, Helm, or Terraform against the private cluster API.

If the OCI Bastion session expires, the tunnel script will exit and ask you to re-run it. That is expected; just create a new session and reopen the tunnel.

### 2. Export kubeconfig in another terminal

The script prepares the dedicated kubeconfig for you. In a separate terminal:

```bash
export KUBECONFIG="$HOME/.kube/oracle-oke-free.yaml"
```

### 3. Verify access

```bash
kubectl get nodes
kubectl get ns
```

Once those commands work, you can run the `platform-bootstrap` stack from your laptop while the tunnel remains open.

## Platform Bootstrap

After the Bastion tunnel is up and `KUBECONFIG` is exported, bootstrap the cluster add-ons from `stacks/platform-bootstrap`:

```bash
cd stacks/platform-bootstrap
../../scripts/tf.sh init -backend-config=backend.hcl
# If you want to keep state local instead, use: ../../scripts/tf.sh init
../../scripts/tf.sh plan
../../scripts/tf.sh apply
```

This stack installs:

- `ingress-nginx` via Helm
- `cert-manager` via Helm
- `argocd` via Helm

If `argocd_bootstrap_enabled = true`, Terraform also bootstraps Argo CD against your GitOps repository by creating:

- an Argo CD repository credential secret for HTTPS access to the private repo
- a root Argo CD `Application` that points at the directory containing child `Application` manifests

The default ingress controller service is configured to request an OCI Network Load Balancer.

For Cloudflare-proxied traffic, the platform stack configures `ingress-nginx` to use Cloudflare's `CF-Connecting-IP` header as the real client IP. The Cloudflare CIDR list is read dynamically with `data "cloudflare_ip_ranges" "cloudflare" {}` and passed to `proxy-real-ip-cidr`, so ingress-nginx only trusts that header when the direct source is Cloudflare.

The infra stack also reads the Cloudflare IPv4 CIDRs dynamically and allows those ranges to reach worker NodePorts. This is required because OCI NLB source preservation makes worker nodes see the Cloudflare edge IP as the packet source instead of an internal VCN source.

When changing this configuration, apply `stacks/infra-free-tier` before `stacks/platform-bootstrap`. That opens the worker NodePort security rules before enabling or updating NLB source preservation, avoiding Cloudflare `522` timeouts during rollout.

If `cert_manager_acme_email`, `cert_manager_dns_zone`, and `cloudflare_api_token` are set, this stack also configures:

- a Cloudflare-backed `ClusterIssuer` for Let's Encrypt staging
- a Cloudflare-backed `ClusterIssuer` for Let's Encrypt production
- a wildcard `Certificate` for `<zone>` and `*.<zone>` in the `ingress-nginx` namespace
- `ingress-nginx` to serve that wildcard certificate as the controller-wide default TLS certificate

If `cloudflare_argocd_dns_record_enabled = true`, Terraform also creates a Cloudflare DNS record for `argocd_hostname` that points at the external `ingress-nginx` load balancer. If `cloudflare_wildcard_dns_record_enabled = true`, Terraform also creates `*.<zone>` against that same target.

After apply, get the initial Argo CD admin password with:

```bash
terraform output argocd_admin_password_command
```

Then run the printed command in a shell with `KUBECONFIG` exported.

If `argocd_hostname` is left as `null`, Argo CD is not exposed through ingress. Access it locally with:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then open:

```text
http://127.0.0.1:8080
```

Use username `admin` and the password retrieved from the initial admin secret.

If `argocd_hostname` is set and the wildcard certificate is enabled, NGINX will terminate TLS with the shared wildcard certificate. Create a DNS record in Cloudflare that points `argocd.<zone>` at the public ingress load balancer.

With Cloudflare DNS automation enabled, Terraform manages that record directly.

### Optional Tailscale Exit Node

The platform stack can run a Tailscale exit node on the existing OKE worker
node. This does not create any additional OCI compute resources.

Before enabling it, create a Tailscale auth key with:

- `tag:exit-node`
- reusable enabled
- pre-authorized enabled
- ephemeral disabled

The tailnet access policy should allow `tag:exit-node` to auto-approve exit-node advertisements.

Enable the add-on in `stacks/platform-bootstrap/terraform.tfvars`:

```hcl
enable_tailscale_exit_node   = true
tailscale_auth_key           = "tskey-auth-..."
tailscale_exit_node_hostname = "oci-oke-exit-node"
```

The Tailscale pod runs privileged with host networking and persists its
Tailscale state in a Kubernetes Secret named `tailscale` so pod restarts keep
the same Tailscale machine identity.

## Argo CD GitOps Bootstrap

1. Terraform installs Argo CD.
2. Terraform creates one root Argo CD `Application`.
3. Argo CD reads the private Git repository and applies the child `Application` manifests stored there.
4. Those child applications then deploy your Helm charts from Git.

For a private GitHub repo over HTTPS with a personal access token, set these variables in `stacks/platform-bootstrap/terraform.tfvars`:

```hcl
argocd_bootstrap_enabled = true
argocd_repo_url          = "https://github.com/jamestjw/cluster-gitops.git"
argocd_repo_username     = "git"
argocd_repo_pat          = "<github-pat>"

argocd_root_application_name     = "root-applications"
argocd_root_application_path     = "argocd"
argocd_root_application_revision = "main"
```

The root application is created directly by Terraform, not from inside the managed Git path. This avoids having the root app manage itself.

After `terraform apply`, verify bootstrap with:

```bash
kubectl -n argocd get applications
```

The root application should appear first, then the child applications from `cluster-gitops/argocd/` should be created by Argo CD.

## Public App TLS

The bootstrap stack can issue and serve a shared wildcard certificate through `ingress-nginx`. With that in place, each application in `cluster-gitops` can keep owning its own `Ingress` resource while reusing the shared certificate at the controller layer.

For app ingresses under the wildcard zone:

- set `spec.ingressClassName: nginx`
- set a unique `spec.rules[].host`
- include a `spec.tls` entry for the host if you want ingress-level TLS intent and redirects
- do not reference the shared wildcard secret from another namespace, because ingress TLS secrets are namespaced

If an app needs its own certificate instead of the shared wildcard certificate, create a namespace-local `Certificate` for that app and reference its secret from that app's `Ingress`.

# Architecture
See `docs/architecture.md` for the detailed design.
