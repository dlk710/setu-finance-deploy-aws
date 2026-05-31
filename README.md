# setu-finance-deploy-aws

Infrastructure and deployment for **Setu Finance** on AWS — low-cost, free-tier
friendly, dev-first, with a documented path to production.

This is the **infra repo**. The application source lives separately in
[`setu-finance`](https://github.com/dlk710/setu-finance). On boot, the instance
clones both: the app repo for source, this repo for the deploy assets below.

## Architecture (single box)

```
            HTTPS (443)
Browser ───────────────► Caddy ──/api──► Express ──► Postgres
                            │              (8787)      (volume)
                            └─ serves the built React app
                            │
                            └─► private S3 contracts bucket (optional cloud storage)
                                                  │ every 2h: pg_dump
                                                  ▼
                                          S3 (Standard, 30-day expiry)
```

One EC2 instance runs Postgres + the Express API + Caddy (automatic HTTPS) via
Docker Compose. No App Runner, RDS, SQS, Lambda, CloudFront, or SES until you
choose to scale.

## Start here (in order)

1. **`FOUNDATIONS.md`** — one-time AWS account setup that keeps your Free Tier
   credits intact (root MFA, IAM admin user, budget, region, tagging).
2. **`terraform/`** — stand up the **dev** box in code. See `terraform/README.md`.
3. **`PROMOTE.md`** — when ready, the checklist to promote to production.

`DEPLOY.md` is the manual (console) version of what Terraform automates — useful
as reference or if you prefer clicking through it once.

## What's in here

| Path | Purpose |
| --- | --- |
| `FOUNDATIONS.md` | Account-level setup checklist (do first) |
| `terraform/` | IaC for the box: EC2 + security group + S3 + IAM role |
| `DEPLOY.md` | Manual deploy runbook (console equivalent) |
| `PROMOTE.md` | Dev → production promotion runbook |
| `Dockerfile` | Builds React + runs Express in one image |
| `compose.yml` | Postgres + API + Caddy stack (env-driven) |
| `Caddyfile` | Auto-HTTPS reverse proxy |
| `deploy.sh` | Selects dev/prod env and brings the stack up |
| `.env.dev.example` / `.env.prod.example` | Env templates (copy, never commit real ones) |
| `bin/backup-to-s3.sh` / `bin/restore.sh` | Postgres backup + restore (every environment) |
| `s3-lifecycle.json` / `iam-policy-s3-backup.json` | Standalone S3/IAM configs (Terraform also creates these) |
| `user-data.sh` | Manual EC2 bootstrap (Terraform renders its own from a template) |

## Cost

Dev box ~**$11/mo while running** (t4g.micro + EBS + public IP), **$0 compute when
stopped** — covered by Free Tier credits. Nothing here touches AWS Organizations,
so your credits stay intact.

## Security note

Never commit real secrets. `.env`, `.env.dev`, `.env.prod`, Terraform state, and
`terraform.tfvars` are gitignored. The bootstrap generates real secrets on the box
at first boot; you set `PORTAL_PASSWORD` and SMTP creds by editing the on-box env file.

## Contract storage on AWS

Setu Finance can keep uploaded client contracts in a private S3 bucket instead of the
instance filesystem. Configure this on the box with:

- `CONTRACTS_S3_BUCKET`
- `CONTRACTS_S3_PREFIX` (optional, defaults to `contracts`)

Recommended pattern:

- use a dedicated private contracts bucket
- allow only the EC2 instance role to `GetObject` and `PutObject`
- keep object keys segmented by `customerCode / year / month / day / timestamp-fileName`
- leave backups and contracts in separate buckets so retention and access can differ
