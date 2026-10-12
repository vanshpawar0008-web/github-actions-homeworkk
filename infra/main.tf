terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

# --------------------------------------------------
# KMS key for S3 encryption
# --------------------------------------------------

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "s3" {
  name          = "alias/homework-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# --------------------------------------------------
# Logging bucket
# --------------------------------------------------

resource "aws_s3_bucket" "log_bucket" {
  bucket = "vanphpawar0008-web-github-actions-logs"
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --------------------------------------------------
# Main homework bucket
# --------------------------------------------------

resource "aws_s3_bucket" "homework_bucket" {
  bucket = "vanphpawar0008-web-github-actions-homework"
}

# --------------------------------------------------
# Public access block
# --------------------------------------------------

resource "aws_s3_bucket_public_access_block" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------
# KMS encryption
# --------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# --------------------------------------------------
# Versioning
# --------------------------------------------------

resource "aws_s3_bucket_versioning" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------
# Access logging
# --------------------------------------------------

resource "aws_s3_bucket_logging" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "homework/"
}

# --------------------------------------------------
# Lifecycle configuration
# --------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  rule {
    id     = "cleanup-old-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# --------------------------------------------------
# Event notifications
# --------------------------------------------------

resource "aws_s3_bucket_notification" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  eventbridge = true
}

# --------------------------------------------------
# Replica bucket
# --------------------------------------------------

resource "aws_s3_bucket" "replica" {
  provider = aws.replica

  bucket = "vanphpawar0008-web-github-actions-replica"
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------
# IAM role for replication
# --------------------------------------------------

resource "aws_iam_role" "replication" {
  name = "s3-homework-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "s3.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]

        Resource = "${aws_s3_bucket.homework_bucket.arn}/*"
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = aws_s3_bucket.homework_bucket.arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]

        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

# --------------------------------------------------
# Cross-region replication
# --------------------------------------------------

resource "aws_s3_bucket_replication_configuration" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-west"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.homework_bucket,
    aws_s3_bucket_versioning.replica
  ]
}