terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#checkov:skip=CKV_AWS_144:Cross-region replication is not required for this local validation bucket
resource "aws_s3_bucket" "homework_bucket" {
  bucket = "vanshpawar0008-web-github-actions-homework"
}

resource "aws_s3_bucket_public_access_block" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "homework_bucket" {
  bucket = aws_s3_bucket.homework_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}