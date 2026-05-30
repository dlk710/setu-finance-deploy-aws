# Role the EC2 instance assumes (no access keys stored on the box).
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "setu-${var.environment}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Least-privilege access to the backups prefix only.
data "aws_iam_policy_document" "backup" {
  statement {
    sid       = "WriteAndReadBackups"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.backups.arn}/backups/*"]
  }
  statement {
    sid       = "ListBucketForRestore"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backups/*"]
    }
  }
}

resource "aws_iam_role_policy" "backup" {
  name   = "setu-${var.environment}-s3-backup"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.backup.json
}

# Optional: allow SSM Session Manager so you can shell in without an SSH key.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "setu-${var.environment}-instance"
  role = aws_iam_role.instance.name
}
