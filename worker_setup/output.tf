output "vpc_id" {
  value = aws_vpc.vpc2.id
}

output "peering_connection_status" {
  value = length(aws_vpc_peering_connection_accepter.accept_from_a) > 0 ? aws_vpc_peering_connection_accepter.accept_from_a[0].accept_status : "not yet configured"
}

output "all_node_public_ips" {
  value = { for k, v in aws_instance.node : k => v.public_ip }
}

output "all_node_private_ips" {
  value = { for k, v in aws_instance.node : k => v.private_ip }
}
