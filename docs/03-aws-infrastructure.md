# 03 - AWS Infrastructure (Terraform)

Status: complete

## Goal

Build a small but realistic AWS environment entirely as Terraform code, with
security controls built in, so that later phases (pipeline scanning and
compliance mapping) have real infrastructure to check and real evidence to
point at.

## Layout

All files live in `infra/` and share one remote state
(`s3://<state-bucket>/infra/terraform.tfstate`, with locking).

| File | Purpose |
|---|---|
| `providers.tf` | Terraform and AWS provider version pins, region, default tags |
| `backend.tf` | S3 remote state with native locking |
| `baseline.tf` | Account-wide security defaults |
| `cloudtrail.tf` | Audit logging and its log bucket |
| `vpc.tf` | Network |
| `variables.tf` | Inputs with validation |
| `ec2.tf` | Firewall, web server, and the on/off cost switch |
| `terraform.tfvars` | Private values (gitignored, never committed) |

## Step 1: security baseline (`baseline.tf`)

| Control | What it does | Compliance idea |
|---|---|---|
| Account-level S3 public access block | Makes it impossible for any bucket in the account to be public | Preventing data exposure |
| EBS encryption by default | Every new disk in eu-west-1 is encrypted | Encryption at rest |
| IAM password policy | 14+ characters, mixed types, no reuse of last 5, no forced expiry | Access control (follows current NIST guidance on rotation) |

Note: EBS default encryption is per region. A fuller baseline would enable it
in every region.

## Step 2: audit logging (`cloudtrail.tf`)

- **CloudTrail** records every API call in the account (who, what, when,
  from where). It is the evidence base for investigations and for SOC 2
  logging and monitoring controls.
- Multi-region trail, so activity in unused regions is also recorded.
- **Log file validation** produces signed digest files that let me prove logs
  were not tampered with.
- Log bucket: versioned, encrypted (AES256), public access blocked, and a
  bucket policy that (a) only lets the CloudTrail service write, and only for
  this trail (`aws:SourceArn` condition, a confused-deputy protection), and
  (b) denies any non-HTTPS access (`aws:SecureTransport`).
- Data events (per-object S3 logging) are intentionally not enabled: they
  cost money.

## Step 3: network (`vpc.tf`)

- VPC `10.0.0.0/16`, one public subnet `10.0.1.0/24` in eu-west-1a,
  internet gateway and route table.
- `map_public_ip_on_launch = false`: instances do not get public IPs unless
  explicitly requested.
- The VPC's **default security group is emptied** (no rules), so it denies
  everything. This is a CIS benchmark control.
- Design trade-off: a truly private subnet would need a NAT gateway to
  download packages, which costs money by the hour. I used one public subnet
  protected by a tight firewall instead.

## Step 4: web server (`ec2.tf`)

- Amazon Linux 2023 `t3.micro`, created by a startup script (**user data**)
  that installs nginx and writes a one-line HTML page.
- **Security group**: inbound HTTP (port 80) from my single IP only. There is
  **no SSH (port 22)** at all. Outbound is limited to ports 80 and 443 for
  package downloads.
- **IMDSv2 required** (`http_tokens = "required"`), which protects the
  instance's metadata credentials from SSRF attacks.
- Root disk explicitly encrypted (gp3).
- **Input validation**: `my_ip_cidr` must be a single `/32` address, so a typo
  cannot open the server to `0.0.0.0/0`.
- **Cost switch**: `deploy_web_server` (default `false`) uses `count` to
  create the instance only on demand. The code is always present for
  scanners; the server only exists during demos.

## Demo and cleanup

1. Set `deploy_web_server = true`, `terraform plan` (1 to add), `apply`.
2. Waited about a minute for boot, opened the output URL: page loaded from my
   IP only over HTTP.
3. Set the switch back to `false`, `apply` (1 to destroy). Instance
   terminated, so no residual disk or compute cost.

Stopping an instance still bills for its disk. Terminating deletes both.

## Known gaps (documented, not hidden)

| Gap | Why accepted | Likely scanner finding |
|---|---|---|
| Web page served over HTTP, not HTTPS | No certificate or domain on a learning project | Unencrypted traffic |
| No VPC flow logs | Adds cost | Flow logs disabled |
| CloudTrail logs not encrypted with a customer-managed KMS key | KMS adds monthly cost | CloudTrail not KMS-encrypted |
| Default VPC still present | Not yet removed | Default VPC in use |
| Egress open to 0.0.0.0/0 on ports 80 and 443 | Needed to install packages | Unrestricted egress |
| No log lifecycle or retention rule on the CloudTrail bucket | Not yet configured | Missing lifecycle policy |
| Instance in a public subnet | NAT gateway costs money | Public instance |

These become the first items fixed or formally risk-accepted in the pipeline
and GRC phases.

## questions/insights

- What does CloudTrail give you, and why enable log file validation? Audit
  trail, plus tamper evidence.
- How do you prevent S3 data exposure at account level? Account-level public
  access block, in addition to per-bucket settings.
- Why no SSH on the instance? No remote login means one fewer attack
  surface. Management can be done through SSM Session Manager.
- What is IMDSv2 and why require it? Session-token-based metadata access,
  which mitigates SSRF credential theft.
- Why `count` with a boolean variable? Cheap, repeatable demos and a
  clean cost control.
- What is a security group vs. a network ACL? Security groups are stateful,
  attached to instances; NACLs are stateless, attached to subnets.
- What did you leave out on purpose and why? Cost-driven decisions, listed
  in the table above.

## Next

- Phase 4: GitHub Actions security pipeline (secret scanning, SAST, IaC
  scanning, SCA, container scanning)
