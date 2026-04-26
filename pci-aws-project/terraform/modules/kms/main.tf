variable "env" {}
variable "project" {}

resource "aws_kms_key" "main" {
  description             = "${var.project}-${var.env}-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "DenyNonEncryptedUploads"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action   = ["kms:Decrypt", "kms:Encrypt"]
        Resource = "*"
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-kms"
    Environment = var.env
    Compliance  = "PCI-DSS-v4"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.env}"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_caller_identity" "current" {}

output "key_id"  { value = aws_kms_key.main.key_id }
output "key_arn" { value = aws_kms_key.main.arn }
