resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" #means about 65,000 addresses.Private
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "devsecops-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "devsecops-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = false

  tags = { Name = "devsecops-public-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" #a public subnet
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "devsecops-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Remove all rules from the VPC's default security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}