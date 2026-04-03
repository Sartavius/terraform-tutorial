terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tfstate-tutorial-bucket"   # <-- replace
    key            = "linux-server/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"  # optional but recommended
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Data ────────────────────────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "server" {
  name        = "${var.server_name}-sg"
  description = "Security group for ${var.server_name}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ── Key Pair (optional – leave key_pair_name empty to skip) ─────────────────

resource "aws_key_pair" "server" {
  count      = var.public_key_path != "" ? 1 : 0
  key_name   = "${var.server_name}-key"
  public_key = file(var.public_key_path)
  tags       = local.common_tags
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.server.id]
  key_name               = var.public_key_path != "" ? aws_key_pair.server[0].key_name : null

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y htop curl wget git
    echo "Server ${var.server_name} ready" >> /var/log/user-data.log
  EOF

  tags = merge(local.common_tags, { Name = var.server_name })
}

# ── Elastic IP (optional) ────────────────────────────────────────────────────

resource "aws_eip" "server" {
  count    = var.assign_elastic_ip ? 1 : 0
  instance = aws_instance.server.id
  domain   = "vpc"
  tags     = local.common_tags
}

# ── Locals ───────────────────────────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.server_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
