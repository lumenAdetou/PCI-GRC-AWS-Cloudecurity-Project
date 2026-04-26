variable "env" {}
variable "project" {}
variable "kms_key_arn" {}
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "db_name"            { default = "pcidb" }
variable "db_username"        { default = "dbadmin" }
variable "db_password"        { sensitive = true }
variable "instance_class"     { default = "db.t3.medium" }

# PCI DSS Req 3 — encrypted database, no public access

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.env}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Compliance = "PCI-DSS-v4" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-rds-sg"
  description = "RDS — allow only from within VPC on 5432"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-${var.env}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = 100
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = true

  backup_retention_period   = 35
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-${var.env}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project}-${var.env}-rds"
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

data "aws_vpc" "selected" { id = var.vpc_id }

output "db_endpoint" { value = aws_db_instance.main.endpoint }
output "db_name"     { value = aws_db_instance.main.db_name }
