output "instance_ids" {
  value = { for name, instance in aws_instance.web : name => instance.id }
}

output "public_ips" {
  value = { for name, instance in aws_instance.web : name => instance.public_ip }
}
