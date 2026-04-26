terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket = "pci-grc-terraform-state-dev"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = local.project
      Environment = local.env
      ManagedBy   = "Terraform"
      Compliance  = "PCI-DSS-v4"
    }
  }
}

locals {
  env     = "dev"
  project = "pci-grc"
}

module "kms" {
  source  = "../../modules/kms"
  env     = local.env
  project = local.project
}

module "networking" {
  source              = "../../modules/networking"
  env                 = local.env
  project             = local.project
  kms_key_arn         = module.kms.key_arn
  vpc_cidr            = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  azs                  = ["us-east-1a", "us-east-1b"]
}

module "iam" {
  source  = "../../modules/iam"
  env     = local.env
  project = local.project
}

module "guardduty" {
  source      = "../../modules/guardduty"
  env         = local.env
  project     = local.project
  kms_key_arn = module.kms.key_arn
}

module "cloudtrail" {
  source      = "../../modules/cloudtrail"
  env         = local.env
  project     = local.project
  kms_key_arn = module.kms.key_arn
}

module "securityhub" {
  source  = "../../modules/securityhub"
  env     = local.env
  project = local.project
}

module "s3" {
  source      = "../../modules/s3"
  env         = local.env
  project     = local.project
  kms_key_arn = module.kms.key_arn
}

module "waf" {
  source  = "../../modules/waf"
  env     = local.env
  project = local.project
  scope   = "REGIONAL"
}

module "rds" {
  source             = "../../modules/rds"
  env                = local.env
  project            = local.project
  kms_key_arn        = module.kms.key_arn
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_password        = var.db_password
  instance_class     = "db.t3.medium"
}

module "eks" {
  source               = "../../modules/eks"
  env                  = local.env
  project              = local.project
  kms_key_arn          = module.kms.key_arn
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_node_role_arn
  node_instance_type   = "t3.medium"
  node_desired         = 2
  node_min             = 1
  node_max             = 4
}

module "lambda" {
  source             = "../../modules/lambda"
  env                = local.env
  project            = local.project
  kms_key_arn        = module.kms.key_arn
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  lambda_role_arn    = module.iam.lambda_role_arn
  s3_bucket          = module.s3.bucket_ids["artifacts"]
  s3_key             = "lambda/pci-compliance-checker.zip"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
