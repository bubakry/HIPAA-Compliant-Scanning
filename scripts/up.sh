#!/usr/bin/env bash
# Stands up the HIPAA-aligned baseline infrastructure.
#
# What this does:
#   1. Validates tools, AWS credentials, and target account.
#   2. Creates (idempotent) the remote-state S3 bucket + DynamoDB lock table.
#   3. terraform init against the S3 backend.
#   4. terraform apply with enable_service=false  (infra + ECR only).
#   5. Runs Checkov and Trivy against the repo and saves reports.
#
# It intentionally does NOT deploy the ECS service. The application image
# bootstrap is handled by the GitHub Actions workflow in .github/workflows/.
#
# Usage:
#   ./scripts/up.sh              # full path
#   ./scripts/up.sh --skip-scans # infra only, no scanner reports

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

SKIP_SCANS="false"
for arg in "$@"; do
  case "${arg}" in
    --skip-scans) SKIP_SCANS="true" ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) fail "Unknown argument: ${arg}" ;;
  esac
done

resolve_config
preflight "provision"
ensure_state_bucket
ensure_lock_table
terraform_init

log "Running terraform apply (enable_service=false, production_safeguards=true)..."
terraform -chdir="${ROOT_DIR}" apply \
  -input=false \
  -auto-approve \
  -var="enable_service=false" \
  -var="production_safeguards=true"

ok "Baseline infrastructure is up."
terraform -chdir="${ROOT_DIR}" output

if [ "${SKIP_SCANS}" = "true" ]; then
  warn "Skipping scanner reports (--skip-scans)."
  exit 0
fi

REPORTS_DIR="${ROOT_DIR}/docs/reports"
mkdir -p "${REPORTS_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"

if command -v checkov >/dev/null 2>&1; then
  log "Running Checkov against the repository..."
  checkov -d "${ROOT_DIR}" \
    --quiet --compact \
    --output cli \
    --output-file-path "${REPORTS_DIR}/checkov-${STAMP}.txt" \
    || warn "Checkov exited non-zero — see ${REPORTS_DIR}/checkov-${STAMP}.txt"
  ok "Checkov report saved to docs/reports/checkov-${STAMP}.txt"
else
  warn "checkov not installed — skipping."
fi

if command -v trivy >/dev/null 2>&1; then
  log "Running Trivy config scan against the repository..."
  trivy config "${ROOT_DIR}" \
    --exit-code 0 \
    --format table \
    --output "${REPORTS_DIR}/trivy-config-${STAMP}.txt" \
    || warn "Trivy exited non-zero — see ${REPORTS_DIR}/trivy-config-${STAMP}.txt"
  ok "Trivy report saved to docs/reports/trivy-config-${STAMP}.txt"
else
  warn "trivy not installed — skipping."
fi

ok "Done. When you're finished presenting, run ./scripts/down.sh to tear everything down."
