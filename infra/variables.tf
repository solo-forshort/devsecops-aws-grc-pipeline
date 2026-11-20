variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.7/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32")
    error_message = "Must be a single IP address ending in /32 (never 0.0.0.0/0)."
  }
}

variable "deploy_web_server" {
  description = "Set true to create the EC2 instance, false to destroy it"
  type        = bool
  default     = false
}
