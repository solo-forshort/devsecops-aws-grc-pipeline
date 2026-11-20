data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  name        = "devsecops-web-sg"
  description = "Web server: HTTP from my IP only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "devsecops-web-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http_from_me" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from my IP only"
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out for package downloads"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "http_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP out for package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_instance" "web" {
  count = var.deploy_web_server ? 1 : 0

  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>DevSecOps portfolio demo</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  user_data_replace_on_change = true

  tags = { Name = "devsecops-web" }
}

output "web_url" {
  value = var.deploy_web_server ? "http://${aws_instance.web[0].public_ip}" : "not deployed"
}