#!/usr/bin/env bash
# Tears the HIPAA-aligned baseline down so you stop paying for it.
#
# What this does:
#   1. Flips production_safeguards=false and re-applies so AWS-side destruction
#      protections (RDS deletion_protection, KMS 30-day window, S3 versioned
#      buckets, ECR force_delete, ALB deletion_protection, Secrets Manager
#      recovery window) are lifted.
#   2. terraform destroy.
#   3. Empties + deletes the remote-state bucket and the DynamoDB lock table.
#   4. Reports any KMS keys still in PendingDeletion (7-day AWS minimum).
#
# Safety:
#   - Prompts for an explicit YES before destroying.
#   - Refuses to run if AWS credentials target a different account than
#     terraform.tfvars expects.
#
# Usage:
#   ./scripts/down.sh           # prompts before destroying
#   ./scripts/down.sh --yes     # skip prompt (CI use)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

AUTO_CONFIRM="false"
for arg in "$@"; do
  case "${arg}" in
    --yes|-y) AUTO_CONFIRM="true" ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *) fail "Unknown argument: ${arg}" ;;
  esac
done

resolve_config
preflight

warn "About to destroy the HIPAA-aligned stack in account ${ACCOUNT_ID_TF} / ${AWS_REGION}."
warn "Resources affected: VPC, RDS, S3 (versioned), KMS CMK, Secrets Manager, CloudTrail, IAM OIDC roles, ECR, ALB (if enabled)."
if [ "${AUTO_CONFIRM}" != "true" ]; then
  printf "Type YES to continue: "
  read -r confirm
  [ "${confirm}" = "YES" ] || fail "Aborted by user."
fi

terraform_init

log "Stage 1/3 — lifting destruction protections (production_safeguards=false)..."
terraform -chdir="${ROOT_DIR}" apply \
  -input=false \
  -auto-approve \
  -var="enable_service=false" \
  -var="production_safeguards=false"

log "Stage 2/3 — terraform destroy..."
terraform -chdir="${ROOT_DIR}" destroy \
  -input=false \
  -auto-approve \
  -var="enable_service=false" \
  -var="production_safeguards=false"

ok "Terraform-managed resources destroyed."

log "Stage 3/3 — removing remote-state bucket and lock table..."

if aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
  log "Emptying state bucket ${STATE_BUCKET} (versions + delete markers)..."
  aws s3api delete-objects \
    --bucket "${STATE_BUCKET}" \
    --region "${AWS_REGION}" \
    --delete "$(aws s3api list-object-versions \
      --bucket "${STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --output json \
      --query '{Objects: Versions[].{Key:Key, VersionId:VersionId}}')" \
    >/dev/null 2>&1 || true
  aws s3api delete-objects \
    --bucket "${STATE_BUCKET}" \
    --region "${AWS_REGION}" \
    --delete "$(aws s3api list-object-versions \
      --bucket "${STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --output json \
      --query '{Objects: DeleteMarkers[].{Key:Key, VersionId:VersionId}}')" \
    >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "${STATE_BUCKET}" --region "${AWS_REGION}"
  ok "State bucket ${STATE_BUCKET} deleted."
else
  warn "State bucket ${STATE_BUCKET} not found — skipping."
fi

if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null
  aws dynamodb wait table-not-exists --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" || true
  ok "Lock table ${LOCK_TABLE} deleted."
else
  warn "Lock table ${LOCK_TABLE} not found — skipping."
fi

log "Listing KMS keys currently in PendingDeletion..."
pending_keys="$(aws kms list-keys --region "${AWS_REGION}" --output json \
  | jq -r '.Keys[].KeyId' \
  | while read -r key_id; do
      state="$(aws kms describe-key --key-id "${key_id}" --region "${AWS_REGION}" \
        --query 'KeyMetadata.KeyState' --output text 2>/dev/null || echo "ERR")"
      if [ "${state}" = "PendingDeletion" ]; then
        echo "${key_id}"
      fi
    done)"

if [ -n "${pending_keys}" ]; then
  warn "KMS keys still in PendingDeletion (AWS enforces a 7-day minimum wait — you cannot shorten this):"
  while IFS= read -r key_id; do
    [ -z "${key_id}" ] && continue
    deletion_date="$(aws kms describe-key --key-id "${key_id}" --region "${AWS_REGION}" \
      --query 'KeyMetadata.DeletionDate' --output text 2>/dev/null || echo "?")"
    printf '  - %s  (deletes at %s)\n' "${key_id}" "${deletion_date}"
  done <<<"${pending_keys}"
else
  ok "No KMS keys in PendingDeletion."
fi

ok "Teardown complete. Run ./scripts/up.sh whenever you want to stand it back up."
