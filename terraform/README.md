# Setu Finance — Terraform (dev now, prod later)

This stack creates the **dev** box in code: one EC2 instance, its security group,
the S3 backup bucket, and an IAM role. The *same* stack becomes production later by
changing a few variables — no rewrite.

## What it creates
- **EC2** `t4g.micro` (Amazon Linux 2023, arm64) running the app via `user_data`
- **Security group** — 443 + 80 open, 22 from your IP only
- **S3 bucket** — backups, 30‑day expiry (used by prod; harmless in dev)
- **IAM role + instance profile** — S3 backup access + SSM Session Manager
- Tags `Project / Environment / Owner / ManagedBy` on everything

## Prerequisites
1. This **`setu-finance-deploy-aws` repo is pushed** (the bootstrap clones it for
   the Dockerfile, compose.yml, Caddyfile, deploy.sh, env templates, and bin/),
   and the **app repo `setu-finance`** is reachable for source.
2. **Terraform** installed locally.
3. AWS credentials for your **IAM admin user** (e.g. `aws configure`).

## Deploy dev
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform plan
terraform apply
```
Then point DNS for `site_address` at the `public_ip` output (or use
`<public_ip>.sslip.io` and skip DNS), wait ~1 minute, and open `https://<site_address>`.
Finish setup (portal password, SMTP) via the `next_steps` output.

## Cost (stays in free tier)
Terraform is free and adds no cost. The dev box is ~**$11/mo while running**
(t4g.micro + EBS + one public IP) and **$0 compute when stopped** — all covered by
your credits. None of these resources touch AWS Organizations, so your credits are safe.

### Save money on dev
Stop the box when you're not using it:
```bash
aws ec2 stop-instances  --instance-ids "$(terraform output -raw instance_id)"
aws ec2 start-instances --instance-ids "$(terraform output -raw instance_id)"
```
With `create_eip = false`, a stopped box isn't billed for a public IP. The trade‑off:
the public IP changes on restart, so re‑point DNS (or use the new `<ip>.sslip.io`).

---

## Progressing to production (future)

Production is the **same stack** with production inputs, kept in its **own state** so
dev and prod never clash. Recommended approach — Terraform workspaces:

```bash
terraform workspace new prod
terraform apply -var-file=prod.tfvars
```

Create `prod.tfvars` from the example with these changes:
```hcl
environment   = "prod"
instance_type = "t4g.small"          # more headroom
create_eip    = true                 # stable IP for real DNS
site_address  = "finance.example.com"
repo_branch   = "main"               # or a release tag like "v1.0.0"
bucket_name   = "setu-finance-backups"   # can reuse; prod writes under backups/prod/
```

What changes automatically when `environment = "prod"`:
- The bootstrap uses `.env.prod` (seeding off — your data is authoritative).
- The 2‑hour backup cron is installed (dev skips it).
- Resource names/tags switch to `setu-prod`.

Then follow **`PROMOTE.md`** for the full release checklist (freeze the branch/tag,
create the bucket lifecycle + IAM if not already, verify, test a backup/restore).

### When you outgrow a single box
See the "paid / scaled phase" section of **`FOUNDATIONS.md`**: separate AWS accounts
(Organizations), RDS/Aurora instead of Postgres‑on‑EC2, ECS Fargate + ALB, CloudFront,
SES, CI/CD. Because everything is already in Terraform and the app is 12‑factor, each of
those is an incremental change to this code — not a restart.

> Note: moving to AWS Organizations / Control Tower / IAM Identity Center ends your Free
> Tier credits and forces the paid plan. Do that step only when you're ready to go paid.
