variable "env" {}
variable "project" {}

# PCI DSS Req 7 & 8 — least privilege roles

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# EKS cluster role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project}-${var.env}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS node role
resource "aws_iam_role" "eks_node" {
  name = "${var.project}-${var.env}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Lambda execution role
resource "aws_iam_role" "lambda" {
  name = "${var.project}-${var.env}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Deny non-MFA policy — PCI DSS Req 8.4
resource "aws_iam_policy" "deny_without_mfa" {
  name        = "${var.project}-${var.env}-deny-no-mfa"
  description = "Deny all actions except MFA management when MFA is not present"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyWithoutMFA"
      Effect = "Deny"
      NotAction = [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "sts:GetSessionToken"
      ]
      Resource = "*"
      Condition = {
        BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" }
      }
    }]
  })
}

output "eks_cluster_role_arn" { value = aws_iam_role.eks_cluster.arn }
output "eks_node_role_arn"    { value = aws_iam_role.eks_node.arn }
output "lambda_role_arn"      { value = aws_iam_role.lambda.arn }
output "deny_mfa_policy_arn"  { value = aws_iam_policy.deny_without_mfa.arn }
