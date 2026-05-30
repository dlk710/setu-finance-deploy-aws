terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state by default ($0). To use a remote S3 backend later, uncomment and
  # create the bucket/lock table first:
  # backend "s3" {
  #   bucket         = "setu-finance-tfstate"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-2"
  #   dynamodb_table = "setu-finance-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  # Applied to every taggable resource (matches FOUNDATIONS.md tagging).
  default_tags {
    tags = {
      Project     = "setu-finance"
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

# Use the account's default VPC + subnets (no NAT/subnet cost for a single box).
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI for arm64 (Graviton / t4g).
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}
