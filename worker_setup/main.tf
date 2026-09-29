locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
    Name        = var.name
  }
}
### 1 - VPC ###
resource "aws_vpc" "vpc2" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name}-vpc2" })
}
### 2 - IGW ###
resource "aws_internet_gateway" "igw2" {
  vpc_id = aws_vpc.vpc2.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw2" })
}
### 3 - PUB SUBNET ###
resource "aws_subnet" "pub_sub2" {
  vpc_id                  = aws_vpc.vpc2.id
  cidr_block               = "10.1.0.0/24"
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true
  tags                     = merge(local.common_tags, { Name = "${var.name}-pub-sub2" })
}

### 4 - PRIVATE SUBNET ###
resource "aws_subnet" "pri_sub2" {
  vpc_id                  = aws_vpc.vpc2.id
  cidr_block               = "10.1.1.0/24"
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true
  tags                     = merge(local.common_tags, { Name = "${var.name}-pri-sub2" })
}
### 5 - PUB ROUTE ####
resource "aws_route_table" "pub_rt2" {
  vpc_id = aws_vpc.vpc2.id
  tags   = merge(local.common_tags, { Name = "${var.name}-pub-rt2" })
  }
resource "aws_route" "pub_rt2_igw" {
  route_table_id         = aws_route_table.pub_rt2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw2.id
}  

### 6 - PRIVATE ROUTE ####
resource "aws_route_table" "pri_rt2" {
  vpc_id = aws_vpc.vpc2.id
  tags   = merge(local.common_tags, { Name = "${var.name}-pri-rt2" })
}
### 7 - PUB SUBNET ASSOC  ####
resource "aws_route_table_association" "pub_rta2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.pub_rt2.id
}
### 8 - PRIVATE SUBNET ASSOC  ####
resource "aws_route_table_association" "pri_rta2" {
  subnet_id      = aws_subnet.pri_sub2.id
  route_table_id = aws_route_table.pri_rt2.id
}
### 9 - SG  ####
resource "aws_security_group" "sg2" {
  name   = "${var.name}-sg2"
  vpc_id = aws_vpc.vpc2.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }

  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "HTTP for Ingress-exposed UIs (Vault, Nexus, Grafana)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "HTTPS for Ingress-exposed UIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "RKE2 supervisor port"
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }

  ingress {
    description = "All traffic from rancherA (peered VPC)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
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
    cidr_blocks = ["10.1.0.0/24"]
  }
  ingress {
    description = "Cluster import traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/24"]
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
    cidr_blocks = [aws_vpc.vpc2.cidr_block]   # internal only — masters/agents reach this, not your laptop
  }
  ingress {
    description = "Puppet master LB frontend"
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc2.cidr_block]
  }
  ingress {
    description = "dnsmasq"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc2.cidr_block]
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

  tags = merge(local.common_tags, { Name = "${var.name}-sg2" })
}
locals {
  # Sizing carried over from the existing HA/std split:
  # master_instance_type_ha = m7i-flex.large (8GB) -> admin (Foreman/PuppetDB)
  # worker_instance_type    = c7i-flex.large (4GB) -> puppetca2
  puppetca_nodes = {
    "puppetca2" = {
      instance_type = var.worker_instance_type
      subnet_id     = aws_subnet.pub_sub2.id
      private_ip    = var.static_private_ips["puppetca2"]
    }
  }
  # Dedicated node for Foreman/PuppetDB — deliberately NOT running any
  # Puppet 5 CA/master role, so foreman-installer's puppet-agent >= 6.15.0
  # requirement can't conflict with anything else on this box.
  admin_nodes = {
    "admin" = {
      instance_type = var.master_instance_type_ha
      subnet_id     = aws_subnet.pub_sub2.id
      private_ip    = var.static_private_ips["admin"]
    }
  }
  # Worker nodes (worker1-3) are managed separately in ../worker_setup-agent
  nodes = merge(local.puppetca_nodes, local.admin_nodes)
}

resource "aws_instance" "node" {
  for_each                      = local.nodes
  ami                           = var.ami_id
  instance_type                 = each.value.instance_type
  subnet_id                     = each.value.subnet_id
  private_ip                    = each.value.private_ip
  associate_public_ip_address   = each.value.subnet_id == aws_subnet.pub_sub2.id ? true : false
  vpc_security_group_ids        = [aws_security_group.sg2.id]
  monitoring                    = var.enable_detailed_monitoring
  key_name                      = "terraform2426"
  iam_instance_profile          = aws_iam_instance_profile.node_profile.name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
  }

  tags = merge(local.common_tags, { Name = "${var.name}-${each.key}" })
}
# Accept peering request from RancherA
resource "aws_vpc_peering_connection_accepter" "accept_from_a" {
  count                      = var.peering_connection_id != "" ? 1 : 0
  vpc_peering_connection_id = var.peering_connection_id
  auto_accept               = true
  tags                      = merge(local.common_tags, { Name = "${var.name}-pcx-b-to-a" })
}

# Route from AWS2 private subnet to AWS1 public subnet
resource "aws_route" "pub_rt2_to_vpc1" {
  count                      = var.peering_connection_id != "" ? 1 : 0
  route_table_id            = aws_route_table.pub_rt2.id
  destination_cidr_block    = "10.0.1.0/24" # AWS VISH PUBLIC SUBNET
  vpc_peering_connection_id = var.peering_connection_id
}

############# LongHorn ##############
# ---------- IAM role for rancherB's nodes (references rancherA's bucket) ----------
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
  count = var.account_a_bucket_name != "" ? 1 : 0
  name  = "${var.name}-s3-backup-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
      Resource = ["arn:aws:s3:::${var.account_a_bucket_name}", "arn:aws:s3:::${var.account_a_bucket_name}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_s3_attach" {
  count      = var.account_a_bucket_name != "" ? 1 : 0
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
