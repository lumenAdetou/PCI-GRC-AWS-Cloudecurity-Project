variable "env" {}
variable "project" {}
variable "kms_key_arn" {}
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "lambda_role_arn" {}
variable "function_name"    { default = "pci-compliance-checker" }
variable "handler"          { default = "handler.lambda_handler" }
variable "runtime"          { default = "python3.12" }
variable "s3_bucket"        {}
variable "s3_key"           {}

# PCI DSS Req 6 — functions deployed in VPC, encrypted env vars

resource "aws_security_group" "lambda" {
  name        = "${var.project}-${var.env}-lambda-sg"
  description = "Lambda — egress only, no inbound"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Compliance = "PCI-DSS-v4" }
}

resource "aws_lambda_function" "main" {
  function_name = "${var.project}-${var.env}-${var.function_name}"
  role          = var.lambda_role_arn
  handler       = var.handler
  runtime       = var.runtime
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key
  timeout       = 60
  memory_size   = 256

  kms_key_arn = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENV     = var.env
      PROJECT = var.project
    }
  }

  tracing_config { mode = "Active" }

  tags = {
    Name        = "${var.project}-${var.env}-${var.function_name}"
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

output "function_name" { value = aws_lambda_function.main.function_name }
output "function_arn"  { value = aws_lambda_function.main.arn }
