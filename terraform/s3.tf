resource "aws_s3_bucket" "backups" {
  bucket = var.bucket_name
}

# Block all public access.
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire backups after 30 days; clean up stale multipart uploads.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-backups-after-30-days"
    status = "Enabled"
    filter {
      prefix = "backups/"
    }
    expiration {
      days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
