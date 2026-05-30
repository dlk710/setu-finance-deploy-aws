# Firewall: HTTPS/HTTP open (80 needed for cert issuance), SSH from your IP only.
resource "aws_security_group" "app" {
  name        = "setu-${var.environment}"
  description = "Setu ${var.environment} web + ssh"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP (Let's Encrypt challenge + redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023_arm64.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    deploy_env         = var.environment
    app_repo_url       = var.app_repo_url
    app_repo_branch    = var.app_repo_branch
    deploy_repo_url    = var.deploy_repo_url
    deploy_repo_branch = var.deploy_repo_branch
    bucket             = var.bucket_name
    site_address       = var.site_address
  })

  tags = {
    Name = "setu-${var.environment}"
  }
}

# Optional static IP (off by default for dev — see variable description).
resource "aws_eip" "app" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"
  tags = {
    Name = "setu-${var.environment}"
  }
}
