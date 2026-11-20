# 02 - Terraform Remote State

Status: complete

## Goal

Store Terraform state in a protected, shared location instead of on my
laptop, so that CI pipelines (GitHub Actions) and future collaborators can
use the same state safely.

## Concepts

- **State file**: Terraform's record of what it built and how each resource
  is configured. It maps the resources in code to the real resources in AWS.
- **State can contain secrets** in plain text (passwords, keys), so it is
  protected like a credential and never committed to Git.
- **Backend**: the Terraform setting that says where state is stored.
- **State locking**: prevents two runs from writing state at the same time,
  which could corrupt it. Terraform 1.10+ supports locking with a lock file
  in S3 itself (`use_lockfile = true`), so no separate DynamoDB table is
  needed. Fewer resources means less cost and less to secure.
- **Bootstrap problem**: the state bucket must exist before Terraform can
  store state in it, but I want Terraform to create it. Solution: a small
  separate `bootstrap/` project creates the bucket using local state.

## Repository layout

```
bootstrap/   creates the S3 state bucket (local state)
infra/       real infrastructure, state stored in the bucket
docs/        documentation
```

## What was built

### bootstrap/ (4 resources)

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` | Holds all Terraform state. `prevent_destroy` stops an accidental `terraform destroy` from deleting it. |
| `aws_s3_bucket_versioning` | Keeps every previous version of the state, allowing recovery from bad writes or deletion. |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypts state at rest with S3-managed keys (AES256, free). |
| `aws_s3_bucket_public_access_block` | Four switches that make the bucket impossible to expose publicly. |

Bucket: `tfstate-sf7391-eu-west-1` (globally unique name: purpose, random
suffix, region).

Provider settings (`providers.tf`):
- `required_version = ">= 1.10"` blocks older Terraform versions.
- AWS provider pinned to `~> 6.0` (any 6.x, never 7.0 unexpectedly).
- `default_tags` stamps every resource with Project, ManagedBy and
  Environment tags, which supports cost tracking and audit evidence.

### infra/ backend

```hcl
terraform {
  backend "s3" {
    bucket       = "tfstate-sf7391-eu-west-1"
    key          = "infra/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

A placeholder `data "aws_region"` source and an output prove the backend
works without creating anything. Backend blocks cannot use variables, so the
bucket name is written literally (a known Terraform limitation).

## Workflow practised

1. `terraform init`: downloads providers, connects the backend.
2. `terraform plan`: dry run. Read the symbols (`+` create, `~` change,
   `-` destroy) and the summary line before approving.
3. `terraform apply`: builds it, after typing `yes`.

## Git hygiene

- `.gitignore` excludes `*.tfstate`, `.terraform/` and `*.tfvars`.
- `.terraform.lock.hcl` **is** committed. It pins exact provider versions so
  every machine and the pipeline install the same ones.

## Known trade-offs

- The bootstrap project's own state is local only. If lost, Terraform would
  forget it created the bucket (recoverable with `terraform import`).
- The state bucket has no access-logging and no policy forcing TLS-only
  access yet. Security scanners in the pipeline will likely flag these, and
  fixing them is planned as a pipeline-driven improvement.
- Encryption uses S3-managed keys rather than a customer-managed KMS key,
  chosen to avoid KMS charges on a free plan.

## some questions and simple answers

- Why remote state? Shared access, locking, encryption, versioning, and the
  pipeline needs it.
- What is in a state file and why is it sensitive? Resource attributes,
  sometimes secrets, in plain text.
- What is the bootstrap problem and how did you solve it? Separate project
  with local state creates the bucket first.
- Why `use_lockfile` instead of DynamoDB? Native S3 locking in Terraform
  1.10+ removes a resource.
- What does `prevent_destroy` do, and what is the downside? Blocks deletion
  by Terraform; you must remove it deliberately to destroy the bucket.
- Why commit `.terraform.lock.hcl` but not state? Lock file is reproducibility
  metadata; state is sensitive and environment-specific.

## Next

- First real AWS infrastructure (networking, logging, secure storage) in `infra/`
- Then the GitHub Actions security pipeline
