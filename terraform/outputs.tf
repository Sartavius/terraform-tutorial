output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.server.id
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = var.assign_elastic_ip ? aws_eip.server[0].public_ip : aws_instance.server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the instance"
  value       = aws_instance.server.public_dns
}

output "security_group_id" {
  description = "ID of the security group attached to the instance"
  value       = aws_security_group.server.id
}

output "ami_id" {
  description = "AMI used for the instance"
  value       = data.aws_ami.amazon_linux.id
}
