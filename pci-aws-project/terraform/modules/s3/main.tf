variable "env" {}
variable "project" {}
variable "kms_key_arn" {}

# PCI DSS Req 3 & 4 — encrypted, versioned, no public access

locals {
  buckets = ["data", "artifacts", "backups"]
}

resource "aws_s3_bucket" "main" {
  for_each      = toset(local.buckets)
  bucket        = "${var.project}-${var.env}-${each.key}"
  force_destroy = false
  tags          = { Compliance = "PCI-DSS-v4", Environment = var.env }
}

resource "aws_s3_bucket_versioning" "main" {
  for_each = aws_s3_bucket.main
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = aws_s3_bucket.main
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  for_each                = aws_s3_bucket.main
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "main" {
  for_each      = aws_s3_bucket.main
  bucket        = each.value.id
  target_bucket = aws_s3_bucket.main["artifacts"].id
  target_prefix = "access-logs/${each.key}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = aws_s3_bucket.main
  bucket   = each.value.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_policy" "deny_non_tls" {
  for_each = aws_s3_bucket.main
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyNonTLS"
      Effect    = "Deny"
      Principal = { AWS = "*" }
      Action    = "s3:*"
      Resource  = ["${each.value.arn}", "${each.value.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

output "bucket_arns" { value = { for k, v in aws_s3_bucket.main : k => v.arn } }
output "bucket_ids"  { value = { for k, v in aws_s3_bucket.main : k => v.id } }
