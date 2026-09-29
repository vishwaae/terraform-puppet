output "vpc_id" {
  value = aws_vpc.vpc1.id
}

output "peering_connection_id" {
  description = "Copy this into rancherB's terraform.tfvars as peering_connection_id"
  value       = length(aws_vpc_peering_connection.a_to_b) > 0 ? aws_vpc_peering_connection.a_to_b[0].id : ""
}


output "all_node_public_ips" {
  value = { for k, v in aws_instance.node : k => v.public_ip }
}

output "all_node_private_ips" {
  value = { for k, v in aws_instance.node : k => v.private_ip }
}
