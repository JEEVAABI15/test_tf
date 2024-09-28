output "instance_public_ip" {
  description = "The public IP of the instance"
  value       = aws_instance.my_ec2.public_ip
}

output "instance_id" {
  description = "The ID of the instance"
  value       = aws_instance.my_ec2.id
}
