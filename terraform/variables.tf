variable "region" {
  description = "AWS home region."
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev or prod). Drives tags and the bootstrap env file."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value (your name or email)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t4g.micro for dev; t4g.small for prod."
  type        = string
  default     = "t4g.micro"
}

variable "root_volume_gb" {
  description = "Root EBS volume size in GB (gp3)."
  type        = number
  default     = 20
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form for SSH access, e.g. 203.0.113.4/32."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH. Leave empty to disable SSH (use SSM)."
  type        = string
  default     = ""
}

variable "create_eip" {
  description = "Attach a static Elastic IP. Keep false for a dev box you stop often (an EIP keeps billing while the instance is stopped; an auto-assigned IP does not)."
  type        = bool
  default     = false
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name for backups."
  type        = string
}

variable "site_address" {
  description = "Public hostname for Caddy/HTTPS, e.g. dev.finance.example.com or <ip>.sslip.io."
  type        = string
}

variable "app_repo_url" {
  description = "Git URL of the application source repo."
  type        = string
  default     = "https://github.com/dlk710/setu-finance.git"
}

variable "app_repo_branch" {
  description = "Branch/tag of the app repo to deploy."
  type        = string
  default     = "main"
}

variable "deploy_repo_url" {
  description = "Git URL of this deploy/infra repo."
  type        = string
  default     = "https://github.com/dlk710/setu-finance-deploy-aws.git"
}

variable "deploy_repo_branch" {
  description = "Branch of the deploy repo to use."
  type        = string
  default     = "main"
}
