locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}

# ---------- Existing network from ../worker_setup (looked up by Name tag, not managed here) ----------
data "aws_vpc" "vpc2" {
  tags = { Name = "${var.name}-vpc2" }
}

data "aws_subnet" "pub_sub2" {
  vpc_id = data.aws_vpc.vpc2.id
  tags   = { Name = "${var.name}-pub-sub2" }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------- Security group for worker nodes ----------
resource "aws_security_group" "worker_sg" {
  name   = "${var.name}-worker-sg"
  vpc_id = data.aws_vpc.vpc2.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "HTTP (nginx on webserver hostgroup)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "Vault UI (infra hostgroup)"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.trusted_cidrs
  }
  ingress {
    description = "All traffic from peered VPC (masters, CA, LBs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.peer_vpc_cidr]
  }
  ingress {
    description = "All traffic within the subnet (admin, puppetca2, workers)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_subnet.pub_sub2.cidr_block]
  }
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name}-worker-sg" })
}

# ---------- IAM: workers may read ONLY the Foreman token parameter ----------
resource "aws_iam_role" "worker_role" {
  name = "${var.name}-worker-role"
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

resource "aws_iam_role_policy" "read_foreman_token" {
  name = "${var.name}-read-foreman-token"
  role = aws_iam_role.worker_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.foreman_token_ssm_param, "/")}"
    }]
  })
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.name}-worker-profile"
  role = aws_iam_role.worker_role.name
}

# ---------- Workers ----------
resource "aws_instance" "worker" {
  for_each                    = var.workers
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.pub_sub2.id
  private_ip                  = each.value.private_ip
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  key_name                    = var.key_name
  monitoring                  = var.enable_detailed_monitoring
  iam_instance_profile        = aws_iam_instance_profile.worker_profile.name

  # cloud-init installs and starts post_script.sh; only the SSM parameter NAME is passed
  user_data = templatefile("${path.module}/templates/worker_user_data.sh.tftpl", {
    post_script_b64 = filebase64("${path.module}/files/post_script.sh")
    ssm_param       = var.foreman_token_ssm_param
    aws_region      = data.aws_region.current.region
  })
  user_data_replace_on_change = true   # new bootstrap = new instance (immutable)

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "optional"
    instance_metadata_tags = "enabled"   # node reads its own Hostname/Hostgroup tags
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name      = "${var.name}-${each.key}"
    Hostname  = each.key
    Hostgroup = each.value.hostgroup
  })
}