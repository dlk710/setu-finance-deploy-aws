# Setu Finance — deploy runbook (minimal, low-cost, free-tier)

One small EC2 box runs the whole stack: **Postgres + Express API + Caddy** (auto‑HTTPS),
serving the built React app. Backups go to **S3 Standard every 2 hours** and auto‑expire
after **30 days**. No App Runner, RDS, SQS, Lambda, CloudFront, or SES.

```
            HTTPS (443)
Browser ───────────────► Caddy ──/api──► Express ──► Postgres
                            │              (8787)      (volume)
                            └─ serves React dist
                                           │
                                           └─► private S3 contracts bucket (optional cloud storage)
                                                  │ every 2h: pg_dump
                                                  ▼
                                          S3 (Standard, 30‑day expiry)
```

## What it costs

On new‑account credits this runs ~**$16–18/mo** (t4g.small + EBS + one public IPv4
at ~$3.60/mo — every public IP is billed since Feb 2024, even an in‑use Elastic IP). Backup storage
is pennies. Credits cover the full 6‑month window. After credits: ~$14/mo, or ~$8/mo on a
t4g.micro with a swap file. Launching the instance and creating the budget also unlock part
of the bonus credits.

---

## 0. One‑time AWS account hygiene
1. Enable **MFA on the root user**; then stop using root.
2. Create an **IAM admin user** (or Identity Center user) for daily work.
3. Create an **AWS Budget** with a low email alert (also earns bonus credit).
4. Work in **one region** (e.g. `us-east-2`).

## 1. Repos
Application source: `setu-finance`. Infra/deploy assets (this bundle): the
`setu-finance-deploy-aws` repo. The bootstrap clones both. Keep real `.env*`
files OUT of git — they're generated on the box.

## 2. Create the S3 backup bucket
Replace the bucket name everywhere if you change it.
```bash
aws s3api create-bucket --bucket setu-finance-backups --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws s3api put-public-access-block --bucket setu-finance-backups \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-lifecycle-configuration --bucket setu-finance-backups \
  --lifecycle-configuration file://s3-lifecycle.json
```

## 2a. Create the private contracts bucket
Use a separate private bucket if you want uploaded client contracts stored in S3 instead
of on the instance filesystem.
```bash
aws s3api create-bucket --bucket setu-finance-contracts --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws s3api put-public-access-block --bucket setu-finance-contracts \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

## 3. Create the instance IAM role
```bash
aws iam create-policy --policy-name setu-s3-backup \
  --policy-document file://iam-policy-s3-backup.json
```
Then in the IAM console: **Create role → EC2 → attach `setu-s3-backup`**. This becomes the
instance profile you attach in step 5.

If you use a separate contracts bucket, also grant the instance role:

- `s3:PutObject`
- `s3:GetObject`

for the contracts bucket path you choose.

## 4. Allocate an Elastic IP and point DNS at it
- Allocate an **Elastic IP** (associate it after the instance launches).
- Add a DNS **A record** for your `SITE_ADDRESS` → the Elastic IP.
  - No domain? Use `<elastic-ip>.sslip.io` as `SITE_ADDRESS` and skip the A record.

## 5. Launch the EC2 instance
- AMI: **Amazon Linux 2023 (arm64)**, type **t4g.small**.
- IAM instance profile: the role from step 3.
- Security group inbound: **443** and **80** from anywhere (80 is needed for the cert
  challenge), **22** from **your IP only**.
- **User data:** paste `user-data.sh` after editing the three values at the top
  (`REPO_URL`, `BUCKET`, `SITE_ADDRESS`).
- After it boots, **associate the Elastic IP** with the instance.

The bootstrap installs Docker, builds the image, brings up the stack, generates real
secrets into `.env`, installs the backup/restore scripts, and schedules the 2‑hour cron.

## 6. Finish configuration
SSH in and set the things the bootstrap left blank:
```bash
sudo nano /opt/setu/app/.env     # set PORTAL_PASSWORD, SMTP_USER/PASS/FROM
                                 # optionally set CONTRACTS_S3_BUCKET / CONTRACTS_S3_PREFIX
cd /opt/setu/app && docker compose -f compose.prod.yml up -d
```
For Gmail/Zelle sync, place the OAuth files under
`/opt/setu/app/server/credentials/` (they are not in git).

To turn on S3-based contract storage, add:

- `CONTRACTS_S3_BUCKET=setu-finance-contracts`
- `CONTRACTS_S3_PREFIX=contracts`

## 7. Verify
```bash
curl -sk https://YOUR_SITE/api/auth/status     # JSON response = API up
docker ps                                       # 3 containers: setu-postgres/api/caddy
sudo /opt/setu/bin/backup-to-s3.sh              # manual backup test
aws s3 ls s3://setu-finance-backups/backups/    # object should appear
```

---

## Restore (when data is lost)
```bash
/opt/setu/bin/restore.sh --list        # see available points (~360 over 30 days)
/opt/setu/bin/restore.sh               # restore the most recent
/opt/setu/bin/restore.sh setu_portal-20260530T140000Z.sql.gz   # a specific one
```
If the whole instance/volume is gone: relaunch with the **same IAM role, security group,
and Elastic IP**, let `user-data.sh` rebuild the stack, then run `restore.sh`.

## Operating notes
- **Max data loss is ~2 hours** (time since the last dump) — matches your tolerance.
- **Watch `/var/log/setu-backup.log`.** Because backups older than 30 days are deleted, a
  silently failing backup means an empty bucket after a month. Glance occasionally, or alert if no
  new object lands.
- `DB_SEED_ON_BOOT=false` in production: a fresh DB comes up with schema only; your restore
  is the source of truth. Flip to `true` if you want the bundled demo data on first boot.
