# DevSecOps on AWS: Terraform, Security Pipelines and GRC

A hands-on portfolio project that builds a small AWS environment entirely as
Terraform code, wraps it in an automated GitHub Actions security pipeline,
and (in progress) maps the controls to compliance frameworks such as SOC 2
and the EU AI Act.

I built it step by step, as a cybersecurity student, to learn the tools,
protocols and infrastructure that DevSecOps and cloud security roles use, and
to document the reasoning behind every decision.

> **Status:** work in progress. Phases 0 to 3 are complete, Phase 4 (the
> security pipeline) is partly complete. See the roadmap below.

## What this project demonstrates

- Secure AWS account foundations: MFA, a non-root IAM user, short-lived credentials, budget alerts
- Infrastructure as Code with Terraform, using encrypted, versioned, locked remote state in S3
- Account-wide security baseline and audit logging (CloudTrail)
- A hardened network and a single web server controlled by a cost-saving on/off switch
- A GitHub Actions pipeline with secret scanning, IaC scanning and SAST
- Supply chain awareness: actions pinned to commit SHAs after the March 2026 Trivy incident
- Honest risk management: known gaps are documented, not hidden

## Repository layout

```
.
├── bootstrap/   Terraform that creates the S3 bucket used for remote state
├── infra/       Main infrastructure (baseline, logging, network, web server)
├── app/         Django inventory app used as the pipeline's sample application
├── docs/        Step-by-step write-ups with interview talking points
└── .github/
    └── workflows/security.yml   The security pipeline
```

## Architecture

| Layer | What is built | Files |
|---|---|---|
| Remote state | Private S3 bucket, versioned, encrypted, public access blocked, native state locking | `bootstrap/`, `infra/backend.tf` |
| Account baseline | Account-wide S3 public access block, default EBS encryption, IAM password policy | `infra/baseline.tf` |
| Audit logging | Multi-region CloudTrail with log file validation, locked-down log bucket (HTTPS-only policy) | `infra/cloudtrail.tf` |
| Network | VPC, one public subnet, internet gateway, emptied default security group | `infra/vpc.tf` |
| Workload | Amazon Linux 2023 t3.micro running nginx, HTTP from one IP only, no SSH, IMDSv2 required, encrypted disk | `infra/ec2.tf` |

Cost control: the server is created only when `deploy_web_server = true`, so
it exists for minutes during a demo and is destroyed afterwards. A zero-spend
AWS budget alert guards the account.

## Security pipeline

Defined in `.github/workflows/security.yml`. Runs on every push to `main`
and on every pull request, with read-only token permissions.

| Check | Tool | Status |
|---|---|---|
| Secret scanning (files and full history) | Gitleaks | Passing |
| IaC scanning (Terraform and Dockerfile) | Trivy, pinned to a commit SHA | Running, report-only |
| SAST (Django and Python code) | Semgrep, pinned image version | Added, results being reviewed |
| SCA (vulnerable dependencies) | Planned | Not started |
| Container image scanning | Planned | Not started |

Scanners start in report-only mode so findings can be triaged first. Once
each finding is fixed or formally accepted, the gates will be switched to
fail the build.

### Current IaC findings (Trivy, HIGH and CRITICAL)

| ID | Severity | Finding | Decision |
|---|---|---|---|
| AWS-0132 (x2) | HIGH | S3 buckets use S3-managed keys, not a customer-managed KMS key | Accepted for now (KMS adds monthly cost); revisit |
| AWS-0015 | HIGH | CloudTrail logs not encrypted with a customer-managed key | Accepted for now; revisit |
| AWS-0104 (x2) | CRITICAL | Security group egress open to 0.0.0.0/0 on ports 80 and 443 | Accepted: outbound only, web ports only, needed to install packages on a short-lived demo server |

The Dockerfile, baseline and network files produced no HIGH or CRITICAL
findings. These results matched the known-gaps table written before the
scanner ever ran (see `docs/03-aws-infrastructure.md`).

## A real supply chain lesson

While building the pipeline, my first Trivy job failed because the tag I
pinned (`0.28.0`) no longer existed. In March 2026 the Trivy GitHub Action
was compromised: attackers rewrote its version tags to point at malicious
code, and the maintainers deleted the old tags during clean-up. The failure
happened before any code ran, so nothing was exposed.

Fix and takeaway: pin third-party actions to a full commit SHA, which cannot be
rewritten, instead of a movable tag, and verify that SHA against the
project's own release page. Hardening the remaining actions the same way is
on the roadmap.

## Documentation

| Doc | Topic |
|---|---|
| [01 Account foundation](docs/01-account-foundation.md) | CLI, MFA, IAM user, temporary credentials, budget, cleanup |
| [02 Terraform remote state](docs/02-terraform-remote-state.md) | State, locking, the bootstrap problem |
| [03 AWS infrastructure](docs/03-aws-infrastructure.md) | Baseline, CloudTrail, VPC, web server, known gaps |

## Running it yourself

Prerequisites: an AWS account, Terraform 1.10 or newer, the AWS CLI, and Git.

1. Authenticate: `aws login` (or your preferred method) and check with `aws sts get-caller-identity`.
2. In `bootstrap/main.tf`, change the bucket name to something globally unique, then:
   `cd bootstrap && terraform init && terraform apply`
3. In `infra/backend.tf`, set the same bucket name.
4. Create `infra/terraform.tfvars` (it is gitignored) with:
   ```
   my_ip_cidr        = "YOUR.PUBLIC.IP/32"
   deploy_web_server = false
   ```
5. `cd infra && terraform init && terraform plan && terraform apply`
6. Set `deploy_web_server = true` and apply to launch the demo server; set it back to `false` and apply to destroy it.

Never commit `terraform.tfvars`, `.env` files, or any `.tfstate` file.

## Roadmap

- [x] Phase 0: account foundation
- [x] Phase 1: repository and Git workflow
- [x] Phase 2: Terraform remote state
- [x] Phase 3: AWS infrastructure
- [ ] Phase 4: security pipeline (secrets and IaC done; SAST in review; SCA and container scanning next)
- [ ] Triage findings, fix or formally accept each one, then enforce the gates
- [ ] Pin all remaining actions to commit SHAs
- [ ] Containerise the Django app and run it on the EC2 instance
- [ ] Phase 5: GRC mapping to SOC 2 and the EU AI Act, with evidence collection (and a Vanta integration if the budget allows)
- [ ] Final write-up

## Disclaimer

This is a learning project built on a free-tier AWS account. It is not a
production system and not compliance advice.
