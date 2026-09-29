output "worker_public_ips" {
  value = { for k, v in aws_instance.worker : k => v.public_ip }
}

output "worker_private_ips" {
  value = { for k, v in aws_instance.worker : k => v.private_ip }
}

output "worker_hostgroups" {
  value = { for k, v in var.workers : k => v.hostgroup }
}
