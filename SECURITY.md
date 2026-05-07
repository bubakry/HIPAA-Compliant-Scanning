# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this repository, please do **not** open a
public GitHub issue. Instead, open a [private security advisory](/security/advisories/new)
on this repository.

Please include:

- A description of the issue and its impact
- Steps to reproduce, or a minimal proof of concept
- The commit SHA or release where the issue was observed
- Any relevant logs, scanner output, or configuration

You will receive an initial acknowledgement within five business days. Coordinated
disclosure is appreciated; once a fix is merged we will credit reporters who
wish to be named.

## Supported Versions

This repository is a reference DevSecOps pipeline rather than a versioned
product. The `main` branch is the only supported version. Forks are encouraged
to track upstream `main` and rebase their customizations.

## Scope

In-scope findings include, but are not limited to:

- Vulnerabilities in the Terraform modules (privilege escalation, missing
  encryption, exposed network paths, IAM weaknesses)
- Misconfigurations in the GitHub Actions workflows (token exposure, weak OIDC
  trust policies, unpinned actions)
- Issues in the FastAPI sample application (dependency CVEs, injection,
  authentication or authorization bypass)
- Secret management and key handling defects

Out of scope:

- Findings that require modifying `terraform.tfvars.example` to insecure
  values not used by the pipeline itself
- Denial-of-service through public scanners against forked deployments
- Social engineering or physical security
