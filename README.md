# HIPAA-Compliant AWS Infrastructure Pipeline with GitHub Actions & Multi-Tool Scanning

A reference DevSecOps pipeline that enforces HIPAA-aligned security controls across Terraform IaC, container images, application code, secrets, and open source dependencies before anything reaches AWS.

The repository uses:

- Terraform `1.14.x` for modular AWS infrastructure
- GitHub Actions as the only CI/CD engine
- GitHub OIDC to assume least-privilege AWS roles without static cloud keys
- ECS Fargate to run a sample FastAPI microservice
- Checkov, tfsec, Trivy, Semgrep, Gitleaks, and OWASP Dependency-Check as mandatory security gates

## Goals

- Implement security measures and prove compliance with HIPAA-aligned controls
- Automate compliance scanning and audit logging
- Provide reusable patterns that other teams can adopt organization-wide
- Shift security left in CI/CD so critical issues never merge or deploy

## Architecture

```mermaid
flowchart LR
    Dev[Developer Push / Pull Request] --> GH[GitHub Actions]

    GH --> IaC[Checkov + tfsec<br/>Terraform misconfiguration scan]
    GH --> App[Semgrep + Gitleaks + Dependency-Check<br/>SAST / secrets / SCA]
    GH --> Container[Docker build + Trivy<br/>image + misconfig scan]

    IaC --> Gate{All required controls pass?}
    App --> Gate
    Container --> Gate

    Gate -- No --> Block[Block PR / fail push]
    Gate -- Yes --> Plan[Terraform plan<br/>OIDC read-only role]
    Plan --> Bootstrap[Terraform apply bootstrap<br/>ECR + core HIPAA infra]
    Bootstrap --> Image[Build and push FastAPI image to ECR]
    Image --> Deploy[Terraform apply service<br/>ECS Fargate + ALB]

    Deploy --> AWS[AWS Account (your-account-id)]

    AWS --> VPC[VPC<br/>public + private + isolated DB subnets]
    AWS --> KMS[KMS CMK<br/>logs, data, secrets, ECR]
    AWS --> S3[S3<br/>regulated data + CloudTrail + ALB logs]
    AWS --> RDS[RDS PostgreSQL<br/>encrypted, Multi-AZ, forced TLS]
    AWS --> CT[CloudTrail + VPC Flow Logs<br/>audit evidence]
    AWS --> ECS[ECS Fargate<br/>private tasks, CloudWatch logs]
```

## Project Structure

```text
.
├── .dockerignore
├── .github
│   └── workflows
│       ├── compliance-scan.yml
│       ├── terraform-apply.yml
│       └── terraform-plan.yml
├── .gitignore
├── .gitleaks.toml
├── .terraform.lock.hcl
├── Dockerfile
├── README.md
├── app
│   ├── __init__.py
│   ├── logging_config.py
│   └── main.py
├── compliance
│   ├── checkov
│   │   ├── config.yaml
│   │   └── policies
│   │       ├── cloudtrail_validation.yaml
│   │       ├── ecs_exec_kms.yaml
│   │       ├── secrets_manager_kms.yaml
│   │       └── tls_listener.yaml
│   ├── dependency-check
│   │   └── suppressions.xml
│   ├── semgrep
│   │   └── hipaa-fastapi.yml
│   ├── tfsec
│   │   └── tfsec.yml
│   └── trivy
│       └── trivy.yaml
├── docs
│   └── screenshots
│       └── .gitkeep
├── main.tf
├── modules
│   ├── ecs-app
│   │   ├── ecr.tf
│   │   ├── ecs.tf
│   │   ├── iam.tf
│   │   ├── main.tf
│   │   ├── networking.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── hipaa-infra
│       ├── cloudtrail.tf
│       ├── iam.tf
│       ├── kms.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── rds.tf
│       ├── s3.tf
│       ├── variables.tf
│       └── vpc.tf
├── outputs.tf
├── providers.tf
├── requirements.txt
├── terraform.tfvars.example
├── tests
│   ├── conftest.py
│   └── test_main.py
└── variables.tf
```

## HIPAA Control Coverage

### Encryption

- KMS customer-managed key protects CloudTrail, CloudWatch Logs, ECR, RDS, and Secrets Manager.
- S3 regulated data bucket enforces SSE-KMS and rejects unencrypted uploads.
- RDS PostgreSQL uses storage encryption, Performance Insights encryption, and forced SSL/TLS.
- ALB terminates HTTPS with `ELBSecurityPolicy-TLS13-1-2-2021-06`.

### Audit Logging

- Multi-region CloudTrail with log file validation is enabled.
- VPC Flow Logs are sent to an encrypted CloudWatch log group.
- ECS application logs are structured JSON in encrypted CloudWatch Logs.
- ALB access logs are enabled in a dedicated log bucket.

### Identity and Access

- GitHub Actions assumes AWS roles through OIDC instead of static keys.
- Separate read-only plan and deployment roles reduce blast radius.
- ECS task and execution roles are split and scoped to required secrets, logs, and S3 access.

### Network and Data Protection

- ECS tasks run in private subnets without public IPs.
- RDS runs in isolated DB subnets behind security-group-only access.
- VPC endpoints remove the need for public internet egress for image pulls, secrets, logs, and exec sessions.

## Security Gates in CI/CD

Every pull request and push runs the full scan stack:

- `Checkov` for Terraform compliance and custom HIPAA checks
- `tfsec` for Terraform misconfigurations
- `Trivy` for Dockerfile, image vulnerabilities, and misconfigurations
- `Semgrep` for Python SAST
- `Gitleaks` for repository secret detection
- `OWASP Dependency-Check` for open source dependency risk

Build behavior:

- Any failed Terraform validation, secret finding, SAST finding, or high/critical vulnerability breaks the workflow.
- Production deployment only starts after the `Compliance Scan` workflow succeeds on a push to `main`.

## What the Pipeline Enforces

### Security and compliance

- Encryption at rest with KMS across core data stores.
- TLS in transit at the ALB and database layer.
- Immutable audit evidence with CloudTrail log file validation and VPC flow logs.
- Blocks insecure Terraform, code, image, and dependency changes before merge.

### Automated scanning and logging

- GitHub Actions runs mandatory scans on every PR and push.
- Ships custom Checkov HIPAA policy files alongside the built-in checks.
- Publishes scanner artifacts and SARIF-compatible outputs.

### Reusability

- Baseline infrastructure module is separated from the workload module.
- CI/CD OIDC, backend state, and deployment sequencing are generic enough to be reused.
- Compliance controls are expressed as code, not tribal knowledge.

### Automation and shift-left

- Terraform owns the infrastructure baseline and ECS deployment target.
- GitHub Actions owns scan, plan, bootstrap, image publish, and gated apply.
- The sample application only deploys after the security gates pass.

## Technologies and Tools

- AWS: VPC, ECS Fargate, ECR, RDS PostgreSQL, KMS, S3, CloudTrail, CloudWatch Logs, Route53, IAM
- IaC: Terraform
- CI/CD: GitHub Actions
- App: Python FastAPI, Uvicorn, Structlog
- Scanners: Checkov, tfsec, Trivy, Semgrep, Gitleaks, OWASP Dependency-Check

## Setup and Deployment

### 1. Fork the repository

Fork this repository into your own GitHub account or organization.

### 2. Create Terraform remote state

Create:

- An S3 bucket for Terraform state
- A DynamoDB table for state locking

The workflows expect these GitHub secrets:

- `TF_STATE_BUCKET`
- `TF_STATE_LOCK_TABLE`

### 3. Configure GitHub OIDC in AWS

Apply the Terraform once locally or through a bootstrap admin context to create:

- `github_actions_plan_role_arn`
- `github_actions_apply_role_arn`

Then store those outputs as GitHub secrets:

- `AWS_TERRAFORM_PLAN_ROLE_ARN`
- `AWS_TERRAFORM_APPLY_ROLE_ARN`

The trust policy is scoped to this repository and the `main` branch / PR events through GitHub OIDC subjects.

### 4. Configure repository variables

Required:

- `ACM_CERTIFICATE_ARN`

Optional:

- `APPLICATION_DOMAIN_NAME`
- `ROUTE53_ZONE_ID`
- `NVD_API_KEY`

If you skip the Route53 values, the service still deploys and exposes the ALB DNS name directly.

### 5. Customize Terraform inputs

Copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Adjust the values that matter for your environment:

- CIDR ranges
- approved ALB ingress CIDRs
- database sizing
- domain and certificate references
- repository name

### 6. Run locally

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate

python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
pytest -q

docker build -t hipaa-fastapi-local:test .
docker run -p 18080:8080 hipaa-fastapi-local:test
curl http://127.0.0.1:18080/health/live
```

### 7. One-command stand-up and teardown

To keep cloud costs bounded while still demonstrating the full baseline, two
scripts wrap the lifecycle end to end:

```bash
./scripts/up.sh         # create state backend + apply infra + run scanners
./scripts/down.sh       # lift safeguards, destroy, delete state backend
```

Configuration precedence (highest first):

1. `TF_VAR_<name>` environment variables — Terraform picks these up natively.
2. AWS Secrets Manager. Set `HIPAA_CONFIG_SECRET=<secret-name>` and store a
   JSON blob like:

   ```json
   {
     "account_id": "123456789012",
     "acm_certificate_arn": "arn:aws:acm:us-east-1:123456789012:certificate/...",
     "application_domain_name": "api.example.com",
     "route53_zone_id": "Z1234567890ABC"
   }
   ```

   Each top-level key is exported as `TF_VAR_<key>` before Terraform runs.
3. `terraform.tfvars` (gitignored local overrides — `cp terraform.tfvars.example terraform.tfvars`).
4. `aws sts get-caller-identity` — the scripts auto-discover `account_id` from
   the AWS caller if nothing else provides it, so you never need to hardcode
   it.

`up.sh` does the following in order:

1. Verifies tools (`aws`, `terraform`, `jq`) and the AWS caller account.
2. Creates the remote-state S3 bucket and DynamoDB lock table (idempotent).
3. Runs `terraform init` against that backend.
4. Applies with `enable_service=false` and `production_safeguards=true` — the
   baseline infrastructure, ECR, and IAM OIDC roles only.
5. Runs Checkov and Trivy against the working tree and saves reports to
   `docs/reports/`.

`down.sh` does the reverse:

1. Re-applies with `production_safeguards=false` so RDS, KMS, Secrets Manager,
   ECR, the ALB, and the versioned S3 buckets drop their protections.
2. Runs `terraform destroy`.
3. Empties and deletes the state bucket and DynamoDB lock table.
4. Reports any KMS keys still in `PendingDeletion`. AWS enforces a 7-day
   minimum wait on KMS key deletion — this is a cloud-side limit and cannot be
   shortened by Terraform.

The ECS service and ALB are intentionally out of scope for the scripts. When
you want to exercise the full workload path, use the GitHub Actions workflows
under [.github/workflows/](.github/workflows/), which handle the two-stage ECR
bootstrap and image push.

### 8. Deployment sequence

The apply workflow intentionally uses two stages:

1. Terraform creates the baseline infrastructure and ECR repository with `enable_service=false`.
2. GitHub Actions builds and pushes the FastAPI image.
3. Terraform applies again with `enable_service=true` and the newly-pushed image URI.

That keeps the pipeline deterministic without hard-coding a container image before ECR exists.

## Design Notes

- The ALB access log bucket is intentionally separate from the regulated data bucket because AWS Application Load Balancer access logs only support `SSE-S3`, while the regulated data bucket enforces `SSE-KMS`.
- The repo is designed so the compliance baseline can be reused even when the application module changes.
- The plan/apply roles are split to support least-privilege CI/CD separation of duties.

## Expected Outcomes and Metrics

- 100% of pushes and PRs are scanned before merge or deployment.
- 0 critical findings are allowed into `main`.
- 0 long-lived AWS credentials are stored in GitHub.
- 100% of regulated storage services use encryption-at-rest controls enforced in Terraform.
- 100% of deployments produce auditable pipeline evidence in GitHub Actions plus AWS logs.

## How Other Teams Can Adopt This Pipeline

- Reuse `modules/hipaa-infra` as the regulated baseline for any AWS service stack.
- Swap `modules/ecs-app` with another workload module while keeping the same OIDC, scan, and remote-state patterns.
- Add more Checkov custom policies as internal compliance requirements grow.
- Extend the Semgrep ruleset for team-specific frameworks without changing the pipeline contract.
- Standardize the same GitHub Actions workflows across repositories to create a consistent security gate.

## Local Verification Completed

This repository was locally verified with:

- `terraform fmt -check -recursive`
- Terraform `1.14.8` `init -backend=false` and `validate`
- `pytest -q`
- `docker build`
- container health check against `/health/live`
