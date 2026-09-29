variable "name"                       { type = string }
variable "environment"                { type = string }
variable "managed_by"                 { type = string }
variable "owner"                      { type = string }
variable "ami_id"                     { type = string }
variable "availability_zone"          { type = string }
variable "root_volume_size"           { type = string }
variable "root_volume_type"           { type = string }
variable "root_volume_encrypted"      { type = bool }
variable "enable_detailed_monitoring" { type = bool }
variable "associate_public_ip_address" { type = bool }

variable "master_instance_type_ha"  { type = string }
variable "master_instance_type_std" { type = string }
variable "worker_instance_type"     { type = string }

variable "trusted_cidrs" { type = list(string) }

variable "peering_connection_id" {
  description = "Peering connection ID created in RancherA"
  type        = string
  default     = ""
}

variable "account_a_bucket_name" {
  type    = string
  default = ""
}

variable "longhorn_disk_size" {
  type    = number
}

variable "static_private_ips" {
  description = "Fixed private IP per node, in pub_sub2 (10.1.0.0/24) — assigned explicitly instead of letting AWS pick dynamically."
  type        = map(string)
}
