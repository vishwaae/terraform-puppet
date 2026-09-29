variable "region"          { type = string }
variable "aws_profile"     { type = string }
variable "name"            { type = string }   # prefix of the network built by ../worker_setup (e.g. htc-b)
variable "environment"     { type = string }
variable "managed_by"      { type = string }
variable "owner"           { type = string }
variable "ami_id"          { type = string }
variable "instance_type"   { type = string }
variable "key_name"        { type = string }
variable "root_volume_size" { type = number }
variable "root_volume_type" { type = string }
variable "enable_detailed_monitoring" { type = bool }

variable "foreman_token_ssm_param" {
  description = "SSM SecureString holding the Foreman API token (value is never in Terraform)"
  type        = string
  default     = "/puppetlab/foreman/api_token"
}

variable "workers" {
  description = "One entry per worker: fixed private IP + Foreman hostgroup (becomes the Hostgroup tag)"
  type = map(object({
    private_ip = string
    hostgroup  = string
  }))
}

variable "trusted_cidrs" {
  description = "Laptop/office public IPs allowed to SSH and browse the workers"
  type        = list(string)
}

variable "peer_vpc_cidr" {
  description = "CIDR of the peered VPC holding the masters, CA and LBs"
  type        = string
  default     = "10.0.0.0/16"
}