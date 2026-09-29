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

variable "account_b_account_id" {
  description = "AWS Account ID of Account B (rancherB) — get it via `aws sts get-caller-identity --profile vidh`"
  type        = string
}

variable "rancherb_vpc_id" {
  description = "VPC ID of RancherB"
  type        = string
  default     = ""
}

variable "longhorn_disk_size" {
  type    = number
  default = 20
}

variable "static_private_ips" {
  description = "Fixed private IP per node, in pub_sub1 (10.0.1.0/24) — assigned explicitly instead of letting AWS pick dynamically, so hostnames/HAProxy/dnsmasq configs never need updating after a rebuild."
  type        = map(string)
}

variable "enable_backup_bucket" {
  description = "Set false to skip the S3 backup bucket + its IAM policy entirely — useful while the account's S3 access is under AWS verification review."
  type        = bool
  default     = true
}