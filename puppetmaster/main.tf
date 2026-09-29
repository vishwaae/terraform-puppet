locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
    Name        = var.name
  }
}
### 1 - VPC ###
resource "aws_vpc" "vpc1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name}-vpc1" })
}
### 2 - IGW ###
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw1" })
}
### 3 - PUB SUBNET ###
resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block               = "10.0.1.0/24"
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true
  tags                     = merge(local.common_tags, { Name = "${var.name}-pub-sub1" })
}

### 4 - PRIVATE SUBNET ###
resource "aws_subnet" "pri_sub1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block               = "10.0.2.0/24"
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true
  tags                     = merge(local.common_tags, { Name = "${var.name}-pri-sub1" })
}
### 5 - PUB ROUTE ####
resource "aws_route_table" "pub_rt1" {
  vpc_id = aws_vpc.vpc1.id
  tags   = merge(local.common_tags, { Name = "${var.name}-pub-rt1" })
}
resource "aws_route" "pub_rt1_igw" {
  route_table_id         = aws_route_table.pub_rt1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw1.id
}

### 6 - PRIVATE ROUTE ####
resource "aws_route_table" "pri_rt1" {
  vpc_id = aws_vpc.vpc1.id
  tags   = merge(local.common_tags, { Name = "${var.name}-pri-rt1" })
}
### 7 - PUB SUBNET ASSOC  ####
resource "aws_route_table_association" "pub_rta1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt1.id
}
### 8 - PRIVATE SUBNET ASSOC  ####
resource "aws_route_table_association" "pri_rta1" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.pri_rt1.id
}
### 9 - SG  ####
resource "aws_security_group" "sg1" {
  name   = "${var.name}-sg1"
  vpc_id = aws_vpc.vpc1.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }

  ingress {
    description = "Rancher UI + downstream cluster-agent registration"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }

  ingress {
    description = "All traffic from rancherB (peered VPC)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
 }
  ingress {
    description = "Allow intra-subnet ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow intra-subnet all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }
  ingress {
    description = "Cluster import traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Cluster import traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kubernetes NodePort range (Cilium Ingress fallback, direct Service access)"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "HAProxy Data Plane API + Swagger GUI"
    from_port   = 5555
    to_port     = 5555
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "Puppet CA LB frontend"
    from_port   = 8141
    to_port     = 8141
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc1.cidr_block]   # internal only — masters/agents reach this, not your laptop
  }
  ingress {
    description = "Puppet master LB frontend"
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc1.cidr_block]
  }
  ingress {
    description = "dnsmasq"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc1.cidr_block]
  }
  ingress {
    description = "Smart Proxy templates (future provisioning work)"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "Smart Proxy API (future provisioning work)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "Foreman Smart Proxy (moved off 8443)"
    from_port   = 8444
    to_port     = 8444
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
    ingress {
    description = "PuppetDB dashboard + API"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "Vault UI"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name}-sg1" })
}

locals {
  master_nodes = {
    "puppetmaster1" = { 
      instance_type = var.master_instance_type_ha
      subnet_id     = aws_subnet.pub_sub1.id
      private_ip    = var.static_private_ips["puppetmaster1"]
    }
    "puppetmaster2" = { 
      instance_type = var.master_instance_type_std 
      subnet_id     = aws_subnet.pub_sub1.id
      private_ip    = var.static_private_ips["puppetmaster2"]
    }
    "puppetmaster3" = { 
      instance_type = var.master_instance_type_std 
      subnet_id     = aws_subnet.pub_sub1.id
      private_ip    = var.static_private_ips["puppetmaster3"]
    }
  }
  puppetca_nodes = {
    "puppetca1" = { 
      instance_type = var.worker_instance_type
      subnet_id     = aws_subnet.pub_sub1.id
      private_ip    = var.static_private_ips["puppetca1"]
    }
  }
  nodes = merge(local.master_nodes, local.puppetca_nodes)
}
### 10 - EC2 ####
resource "aws_instance" "node" {
  for_each                      = local.nodes
  ami                           = var.ami_id
  instance_type                 = each.value.instance_type
  subnet_id                     = each.value.subnet_id
  private_ip                    = each.value.private_ip
  associate_public_ip_address   = each.value.subnet_id == aws_subnet.pub_sub1.id ? true : false
  vpc_security_group_ids        = [aws_security_group.sg1.id]
  monitoring                    = var.enable_detailed_monitoring
  key_name                      = "terraform2425"
  iam_instance_profile          = aws_iam_instance_profile.node_profile.name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
  }

  tags = merge(local.common_tags, { Name = "${var.name}-${each.key}" })
}

#### eth1 interface
resource "aws_network_interface" "puppetmaster1_eth1" {
  subnet_id       = aws_subnet.pub_sub1.id
  security_groups = [aws_security_group.sg1.id]
  private_ips     = ["10.0.1.251"]
  tags            = merge(local.common_tags, { Name = "${var.name}-puppetmaster1-eth1-foreman" })
}

resource "aws_network_interface_attachment" "puppetmaster1_eth1_attach" {
  instance_id          = aws_instance.node["puppetmaster1"].id
  network_interface_id = aws_network_interface.puppetmaster1_eth1.id
  device_index         = 1
}
# VPC Peering request from RancherA to RancherB — skipped entirely until
# rancherB actually exists (rancherb_vpc_id set to a real value). Comes
# online automatically on a later apply once worker1-3/puppetca2 are up,
# with no other changes needed here.
resource "aws_vpc_peering_connection" "a_to_b" {
  count         = var.rancherb_vpc_id != "" ? 1 : 0
  vpc_id        = aws_vpc.vpc1.id
  peer_vpc_id   = var.rancherb_vpc_id
  peer_owner_id = var.account_b_account_id

  auto_accept   = false

  tags = merge(local.common_tags, { Name = "${var.name}-pcx-a-to-b" })
}
# Route from AWS1 public subnet to AWS2 private subnet

resource "aws_route" "pub_rt1_to_vpc2_private" {
  count                      = var.rancherb_vpc_id != "" ? 1 : 0
  route_table_id            = aws_route_table.pub_rt1.id
  destination_cidr_block    = "10.1.0.0/24"   # AWS2 private subnet
  vpc_peering_connection_id = aws_vpc_peering_connection.a_to_b[0].id
}

####below S3 ##########
# ---------- Backup storage: S3 bucket for Velero + RKE2 etcd snapshots ----------
data "aws_caller_identity" "current" {}

locals {
  backup_bucket_name = "${var.name}-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "backups" {
  count  = var.enable_backup_bucket ? 1 : 0
  bucket = local.backup_bucket_name
  tags   = merge(local.common_tags, { Name = local.backup_bucket_name })
}

resource "aws_s3_bucket_versioning" "backups" {
  count  = var.enable_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count                   = var.enable_backup_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.backups[0].id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.enable_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "backups_cross_account" {
  count  = var.enable_backup_bucket && var.rancherb_vpc_id != "" ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAOwnerFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.backups[0].arn, "${aws_s3_bucket.backups[0].arn}/*"]
      },
      {
        Sid       = "AccountBNodeRoleReadWrite"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_b_account_id}:role/htc-b-node-role" }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource  = [aws_s3_bucket.backups[0].arn, "${aws_s3_bucket.backups[0].arn}/*"]
      },
    ]
  })
}

# ---------- IAM role for rancherA's own nodes ----------
resource "aws_iam_role" "node_role" {
  name = "${var.name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_policy" "s3_backup_policy" {
  count = var.enable_backup_bucket ? 1 : 0
  name  = "${var.name}-s3-backup-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
      Resource = [aws_s3_bucket.backups[0].arn, "${aws_s3_bucket.backups[0].arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_s3_attach" {
  count      = var.enable_backup_bucket ? 1 : 0
  role       = aws_iam_role.node_role.name
  policy_arn = aws_iam_policy.s3_backup_policy[0].arn
}

resource "aws_iam_instance_profile" "node_profile" {
  name = "${var.name}-node-profile"
  role = aws_iam_role.node_role.name
}

# ---------- Longhorn: second EBS disk on every node ----------
resource "aws_ebs_volume" "longhorn_disk" {
  for_each          = local.nodes
  availability_zone = var.availability_zone
  size              = var.longhorn_disk_size
  type              = "gp3"
  encrypted         = true
  tags              = merge(local.common_tags, { Name = "${var.name}-${each.key}-longhorn" })
}

resource "aws_volume_attachment" "longhorn_attach" {
  for_each    = local.nodes
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.longhorn_disk[each.key].id
  instance_id = aws_instance.node[each.key].id
}