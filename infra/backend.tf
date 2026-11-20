terraform {
  backend "s3" {
    bucket       = "tfstate-sf7391-eu-west-1"
    key          = "infra/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}