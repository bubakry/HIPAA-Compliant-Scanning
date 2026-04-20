#!/usr/bin/env bash
# Shared helpers for up.sh and down.sh.
# Sourced, not executed directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

color_red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
color_green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
color_amber() { printf '\033[0;33m%s\033[0m\n' "$*"; }
color_cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }

log()   { color_cyan  "[$(date +%H:%M:%S)] $*"; }
ok()    { color_green "[$(date +%H:%M:%S)] $*"; }
warn()  { color_amber "[$(date +%H:%M:%S)] $*"; }
fail()  { color_red   "[$(date +%H:%M:%S)] $*"; exit 1; }

require_tool() {
  local tool="$1"
  command -v "${tool}" >/dev/null 2>&1 || fail "Required tool '${tool}' is not installed."
}

load_tfvar() {
  # Reads a single scalar value from terraform.tfvars. Falls back to terraform.tfvars.example.
  local key="$1"
  local file="${ROOT_DIR}/terraform.tfvars"
  [ -f "${file}" ] || file="${ROOT_DIR}/terraform.tfvars.example"
  awk -F '=' -v k="${key}" '
    $1 ~ "^[[:space:]]*"k"[[:space:]]*$" {
      sub(/^[[:space:]]*/, "", $2)
      sub(/[[:space:]]*#.*$/, "", $2)
      gsub(/"/, "", $2)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "${file}"
}

load_secret_config() {
  # If HIPAA_CONFIG_SECRET is set, pull the named Secrets Manager secret and
  # export each top-level JSON key as TF_VAR_<key>, which Terraform picks up
  # natively. Existing TF_VAR_* env vars always win.
  [ -n "${HIPAA_CONFIG_SECRET:-}" ] || return 0
  require_tool aws
  require_tool jq

  log "Fetching Terraform variables from Secrets Manager secret '${HIPAA_CONFIG_SECRET}'..."
  local payload
  payload="$(aws secretsmanager get-secret-value \
    --secret-id "${HIPAA_CONFIG_SECRET}" \
    --query SecretString \
    --output text 2>/dev/null || true)"
  [ -n "${payload}" ] || fail "Unable to read secret '${HIPAA_CONFIG_SECRET}'. Check the name and your AWS credentials."
  jq empty <<<"${payload}" 2>/dev/null || fail "Secret '${HIPAA_CONFIG_SECRET}' is not valid JSON."

  while IFS='=' read -r key value; do
    [ -z "${key}" ] && continue
    local env_name="TF_VAR_${key}"
    if [ -n "${!env_name:-}" ]; then
      continue
    fi
    export "${env_name}=${value}"
  done < <(jq -r 'to_entries[] | "\(.key)=\(.value | if type==\"string\" then . else tostring end)"' <<<"${payload}")

  ok "Loaded Terraform variables from Secrets Manager."
}

resolve_config() {
  load_secret_config

  PROJECT_NAME="${TF_VAR_project_name:-$(load_tfvar project_name)}"
  ENVIRONMENT="${TF_VAR_environment:-$(load_tfvar environment)}"
  AWS_REGION_TF="${TF_VAR_aws_region:-${AWS_REGION:-${AWS_DEFAULT_REGION:-$(load_tfvar aws_region)}}}"
  ACCOUNT_ID_TF="${TF_VAR_account_id:-$(load_tfvar account_id)}"

  : "${PROJECT_NAME:?project_name is not set — export TF_VAR_project_name or add it to terraform.tfvars}"
  : "${ENVIRONMENT:?environment is not set — export TF_VAR_environment or add it to terraform.tfvars}"
  : "${AWS_REGION_TF:?aws_region is not set — export TF_VAR_aws_region or AWS_REGION}"

  # Auto-discover account_id from the caller if nothing else provided it, or if
  # the tfvars placeholder (000000000000) is in effect.
  if [ -z "${ACCOUNT_ID_TF}" ] || [ "${ACCOUNT_ID_TF}" = "000000000000" ]; then
    require_tool aws
    require_tool jq
    local discovered
    discovered="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
    [ -n "${discovered}" ] || fail "Could not auto-discover account_id. Export TF_VAR_account_id or run 'aws sso login'."
    ACCOUNT_ID_TF="${discovered}"
    ok "Auto-discovered account_id ${ACCOUNT_ID_TF} from the AWS caller."
  fi

  # Propagate everything Terraform will need as TF_VAR_* for downstream calls.
  export TF_VAR_project_name="${PROJECT_NAME}"
  export TF_VAR_environment="${ENVIRONMENT}"
  export TF_VAR_aws_region="${AWS_REGION_TF}"
  export TF_VAR_account_id="${ACCOUNT_ID_TF}"

  export AWS_REGION="${AWS_REGION_TF}"
  export AWS_DEFAULT_REGION="${AWS_REGION_TF}"

  local sanitized
  sanitized="$(printf '%s' "${PROJECT_NAME}-${ENVIRONMENT}" | tr '[:upper:]_' '[:lower:]-' | cut -c1-40)"
  STATE_BUCKET="${sanitized}-tfstate-${ACCOUNT_ID_TF}"
  LOCK_TABLE="${sanitized}-tflock"
  STATE_KEY="${PROJECT_NAME}/${ENVIRONMENT}/terraform.tfstate"
}

preflight() {
  local operation="${1:-provision}"

  require_tool aws
  require_tool terraform
  require_tool jq

  [ -f "${ROOT_DIR}/terraform.tfvars" ] || warn "terraform.tfvars not found — using env vars, Secrets Manager, and example defaults."

  local caller
  caller="$(aws sts get-caller-identity --output json 2>/dev/null || true)"
  [ -n "${caller}" ] || fail "Unable to reach AWS STS. Run 'aws sso login' or configure credentials, then retry."

  local caller_account caller_arn
  caller_account="$(jq -r '.Account' <<<"${caller}")"
  caller_arn="$(jq -r '.Arn' <<<"${caller}")"
  if [ "${caller_account}" != "${ACCOUNT_ID_TF}" ]; then
    fail "AWS credentials target account ${caller_account} but resolved config expects ${ACCOUNT_ID_TF}. Refusing to continue."
  fi

  if [ -n "${HIPAA_BLOCKED_ACCOUNTS:-}" ]; then
    local blocked
    IFS=',' read -ra blocked <<<"${HIPAA_BLOCKED_ACCOUNTS}"
    for entry in "${blocked[@]}"; do
      entry="${entry// /}"
      if [ "${caller_account}" = "${entry}" ]; then
        fail "Account ${caller_account} is in HIPAA_BLOCKED_ACCOUNTS. Switch AWS_PROFILE and retry."
      fi
    done
  fi

  ok "AWS credentials resolved to account ${caller_account} in ${AWS_REGION}."

  if [ "${HIPAA_SKIP_CONFIRM:-}" = "true" ]; then
    warn "HIPAA_SKIP_CONFIRM=true — skipping interactive confirmation."
    return
  fi

  echo
  echo "About to ${operation} HIPAA baseline infrastructure on:"
  echo "  account: ${caller_account}"
  echo "  region:  ${AWS_REGION}"
  echo "  caller:  ${caller_arn}"
  echo
  printf "Type YES to proceed: "
  local answer=""
  read -r answer
  [ "${answer}" = "YES" ] || fail "Aborted by user."
}

ensure_state_bucket() {
  if aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
    ok "State bucket ${STATE_BUCKET} already exists."
    return
  fi

  log "Creating state bucket ${STATE_BUCKET}..."
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${STATE_BUCKET}" --region "${AWS_REGION}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
  fi

  aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null

  aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET}" \
    --versioning-configuration Status=Enabled >/dev/null

  aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET}" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' >/dev/null

  ok "State bucket ${STATE_BUCKET} ready (versioning + SSE-S3 + public access blocked)."
}

ensure_lock_table() {
  if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    ok "Lock table ${LOCK_TABLE} already exists."
    return
  fi

  log "Creating DynamoDB lock table ${LOCK_TABLE}..."
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" >/dev/null

  aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${AWS_REGION}"
  ok "Lock table ${LOCK_TABLE} ready."
}

terraform_init() {
  log "Initializing Terraform backend..."
  terraform -chdir="${ROOT_DIR}" init -reconfigure -input=false \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="key=${STATE_KEY}" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=${LOCK_TABLE}" \
    -backend-config="encrypt=true"
}
