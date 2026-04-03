variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "server_name" {
  description = "Name tag applied to the instance and related resources"
  type        = string
  default     = "linux-server"
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "public_key_path" {
  description = "Path to your SSH public key file. Leave empty to skip key pair creation."
  type        = string
  default     = ""
}

variable "assign_elastic_ip" {
  description = "Whether to assign an Elastic IP to the instance"
  type        = bool
  default     = false
}
