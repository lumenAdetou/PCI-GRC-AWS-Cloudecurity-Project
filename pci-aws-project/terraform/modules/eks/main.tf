variable "env" {}
variable "project" {}
variable "kms_key_arn" {}
variable "vpc_id" {}
variable "private_subnet_ids"  { type = list(string) }
variable "eks_cluster_role_arn" {}
variable "eks_node_role_arn" {}
variable "k8s_version"          { default = "1.30" }
variable "node_instance_type"   { default = "t3.medium" }
variable "node_desired"         { default = 2 }
variable "node_min"             { default = 2 }
variable "node_max"             { default = 5 }

# PCI DSS Req 1, 6, 10 — isolated cluster with encryption and audit logging

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}-${var.env}-eks-cluster-sg"
  description = "EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_eks_cluster" "main" {
  name     = "${var.project}-${var.env}-cluster"
  role_arn = var.eks_cluster_role_arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    provider { key_arn = var.kms_key_arn }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name        = "${var.project}-${var.env}-eks"
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-${var.env}-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }

  update_config { max_unavailable = 1 }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version_number
  }

  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_launch_template" "node" {
  name_prefix = "${var.project}-${var.env}-node-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Compliance = "PCI-DSS-v4" }
  }
}

output "cluster_name"     { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_ca"       { value = aws_eks_cluster.main.certificate_authority[0].data }
