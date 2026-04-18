# oracle-tf

Terraform layout for a small, professional OCI OKE platform on Free Tier.

## Target Design

- Private OKE API endpoint
- Single Ampere worker node to start
- `VM.Standard.A1.Flex` with `1` OCPU and `6` GB RAM
- `ingress-nginx` exposed through an OCI Network Load Balancer
- Argo CD bootstrapped from inside the VCN after cluster creation

## Stack Strategy

This repository should be split into two Terraform stacks plus a bootstrap path:

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

## Why This Is The Professional Split

- Private control plane stays private.
- Terraform does not depend on a fragile local tunnel for the first stack.
- In-cluster resources are applied only from a network path that can reliably reach the Kubernetes API.
- Argo CD becomes the steady-state deployment mechanism after bootstrap.

See `docs/architecture.md` for the detailed design.
