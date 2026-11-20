# Block public access to ALL S3 buckets in this account
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt every new EBS disk in this region by default
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# Strong password rules for IAM users with console access
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  password_reuse_prevention      = 5
  allow_users_to_change_password = true
}