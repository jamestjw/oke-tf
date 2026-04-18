#!/usr/bin/env bash

set -euo pipefail

TF_STACK_DIR="${TF_STACK_DIR:-$(pwd)/stacks/infra-free-tier}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-${SSH_PRIVATE_KEY}.pub}"
LOCAL_PORT="${LOCAL_PORT:-16443}"
OCI_REGION="${OCI_REGION:-ca-montreal-1}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/oracle-oke-free.yaml}"
SETUP_KUBECONFIG="${SETUP_KUBECONFIG:-true}"

terraform_output() {
  terraform -chdir="${TF_STACK_DIR}" output -raw "$1"
}

if [[ -z "${BASTION_ID:-}" ]]; then
  BASTION_ID="$(terraform_output bastion_id)"
fi

if [[ -z "${OKE_CLUSTER_ID:-}" ]]; then
  OKE_CLUSTER_ID="$(terraform_output oke_cluster_id)"
fi

if [[ -z "${OKE_PRIVATE_ENDPOINT:-}" ]]; then
  OKE_PRIVATE_ENDPOINT="$(terraform_output oke_private_endpoint)"
fi

if [[ -z "${OKE_API_HOST:-}" ]]; then
  OKE_API_HOST="${OKE_PRIVATE_ENDPOINT%%:*}"
fi

if [[ -z "${OKE_API_PORT:-}" ]]; then
  OKE_API_PORT="${OKE_PRIVATE_ENDPOINT##*:}"
fi

if [[ -z "${BASTION_SESSION_ID:-}" ]]; then
  if [[ ! -f "${SSH_PUBLIC_KEY}" ]]; then
    printf 'SSH public key not found: %s\n' "${SSH_PUBLIC_KEY}" >&2
    exit 1
  fi

  BASTION_SESSION_ID="$({
    oci bastion session create-port-forwarding \
      --bastion-id "${BASTION_ID}" \
      --target-private-ip "${OKE_API_HOST}" \
      --target-port "${OKE_API_PORT}" \
      --ssh-public-key-file "${SSH_PUBLIC_KEY}" \
      --key-type PUB \
      --display-name "oke-api-port-forward" \
      --query 'data.id' \
      --raw-output
  })"

  while true; do
    SESSION_STATE="$(oci bastion session get --session-id "${BASTION_SESSION_ID}" --query 'data."lifecycle-state"' --raw-output)"

    if [[ "${SESSION_STATE}" == "ACTIVE" ]]; then
      break
    fi

    if [[ "${SESSION_STATE}" == "FAILED" || "${SESSION_STATE}" == "DELETED" ]]; then
      printf 'Bastion session entered unexpected state: %s\n' "${SESSION_STATE}" >&2
      exit 1
    fi

    sleep 2
  done

  printf 'Created Bastion session: %s\n' "${BASTION_SESSION_ID}"
fi

if [[ "${SETUP_KUBECONFIG}" == "true" ]]; then
  mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

  oci ce cluster create-kubeconfig \
    --cluster-id "${OKE_CLUSTER_ID}" \
    --file "${KUBECONFIG_PATH}" \
    --region "${OCI_REGION}" \
    --token-version 2.0.0 \
    --kube-endpoint PRIVATE_ENDPOINT >/dev/null

  CLUSTER_NAME="$(KUBECONFIG="${KUBECONFIG_PATH}" kubectl config get-clusters | awk 'NR==2 {print $1}')"
  KUBECONFIG="${KUBECONFIG_PATH}" kubectl config set-cluster "${CLUSTER_NAME}" --server="https://127.0.0.1:${LOCAL_PORT}" >/dev/null

  printf 'Prepared kubeconfig: %s\n' "${KUBECONFIG_PATH}"
  printf 'In another terminal run:\n'
  printf 'export KUBECONFIG=%q\n' "${KUBECONFIG_PATH}"
fi

printf 'Forwarding 127.0.0.1:%s to %s:%s through Bastion session %s\n' \
  "${LOCAL_PORT}" \
  "${OKE_API_HOST}" \
  "${OKE_API_PORT}" \
  "${BASTION_SESSION_ID}"

SSH_ARGS=(
  -S none
  -o ControlMaster=no
  -o IdentitiesOnly=yes
  -i "${SSH_PRIVATE_KEY}"
  -N
  -L "${LOCAL_PORT}:${OKE_API_HOST}:${OKE_API_PORT}"
  -p 22
  "${BASTION_SESSION_ID}@host.bastion.${OCI_REGION}.oci.oraclecloud.com"
)

MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-3}"

for attempt in $(seq 1 "${MAX_RETRIES}"); do
  ssh "${SSH_ARGS[@]}"
  ssh_exit_code=$?

  if [[ "${ssh_exit_code}" -eq 0 ]]; then
    exit 0
  fi

  if [[ "${ssh_exit_code}" -eq 130 ]]; then
    # SSH tunnel interrupted by user with ctrl+c
    exit 130
  fi

  if [[ "${attempt}" -lt "${MAX_RETRIES}" ]]; then
    printf 'SSH tunnel attempt %s/%s failed, retrying in %s seconds...\n' \
      "${attempt}" \
      "${MAX_RETRIES}" \
      "${RETRY_DELAY_SECONDS}"
    sleep "${RETRY_DELAY_SECONDS}"
  fi
done

printf 'SSH tunnel failed after %s attempts\n' "${MAX_RETRIES}" >&2
exit 1
