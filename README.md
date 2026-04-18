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
- `argocd` via Helm

If `argocd_bootstrap_enabled = true`, Terraform also bootstraps Argo CD against your GitOps repository by creating:

- an Argo CD repository credential secret for HTTPS access to the private repo
- a root Argo CD `Application` that points at the directory containing child `Application` manifests

The default ingress controller service is configured to request an OCI Network Load Balancer.

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

# Architecture
See `docs/architecture.md` for the detailed design.
