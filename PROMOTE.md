# Setu Finance — dev now, production in ~2 weeks

The trick: dev and prod are the **same** files (`Dockerfile`, `compose.yml`,
`Caddyfile`, `deploy.sh`). Only the env file differs. So promotion is a config
switch + a deploy, never a rewrite.

```
        same bundle, different env file
 .env.dev  ──►  deploy.sh dev   ──►  dev box   (dev.finance.example.com)
 .env.prod ──►  deploy.sh prod  ──►  prod box  (finance.example.com)
```

---

## Now: stand up DEV

1. Commit the infra assets to the `setu-finance-deploy-aws` repo (Dockerfile,
   compose.yml, Caddyfile, deploy.sh, .env.*.example, bin/*, terraform/). The
   bootstrap clones it alongside the app repo.
2. DNS: point `dev.finance.example.com` at the dev box's public IP
   (or use `<ip>.sslip.io` if you have no domain yet).
3. Launch a small, cheap box for dev:
   - **t4g.micro**, Amazon Linux 2023 (arm64).
   - Security group: 443 + 80 open, 22 from your IP.
   - User data: `user-data.sh` with `DEPLOY_ENV="dev"` and the dev `SITE_ADDRESS`.
   - No IAM backup role needed for dev (data is disposable).
4. Develop against it for two weeks. **Stop the instance when you're not using it**
   — a stopped box costs $0 compute (just ~$1.60/mo for the disk). Releasing its
   public IP while stopped avoids the ~$3.60/mo IPv4 charge too.

Everyday code changes don't need a rebuild from scratch:
```bash
cd /opt/setu/app && git pull && ./deploy.sh dev
```

## In ~2 weeks: promote to PROD

Prod is a **separate box** (clean isolation from dev). Nothing about dev is reused
except the tested code.

1. Freeze the release: merge your tested changes to `main` (and optionally tag,
   e.g. `v1.0.0`).
2. Create the prod backup infrastructure (once) — bucket, 30‑day lifecycle, IAM
   role — per `DEPLOY.md` steps 2–3.
3. DNS: point `finance.example.com` at the prod box's Elastic IP.
4. Launch the prod box:
   - **t4g.small**, Amazon Linux 2023 (arm64), with the **backup IAM role** attached.
   - Same security group rules.
   - User data: `user-data.sh` with `DEPLOY_ENV="prod"`, `REPO_BRANCH="main"`
     (or your tag), and the prod `SITE_ADDRESS`.
   - This keeps the 2‑hour backup cron in place with the `prod` backup prefix.
5. Set real prod secrets: edit `/opt/setu/app/.env.prod` (PORTAL_PASSWORD, SMTP),
   then `./deploy.sh prod`. Add Gmail OAuth files under
   `server/credentials/` if you use Zelle sync.
6. Verify: `curl -sk https://finance.example.com/api/auth/status`, `docker ps`,
   and one manual `/opt/setu/bin/backup-to-s3.sh prod`.

After prod is live you can terminate the dev box (or keep it stopped and start it
only when working on the next change).

## What carries over vs. what doesn't

- **Code** carries over via git (branch/tag) — that's the whole point of promotion.
- **Data does NOT** carry over. Prod starts clean (`DB_SEED_ON_BOOT=false`); dev's
  demo data stays in dev. This is intended — you don't want test data in prod.
- **Secrets are per‑env** — separate `.env.dev` / `.env.prod`, different passwords.
- **Backups are prod‑only**, under the `backups/prod/` prefix.

## Cost while running both (during the 2-week overlap, if any)

Within your 6‑month credits everything here is covered. Out of pocket later:
dev (t4g.micro, mostly stopped) ~$2–11/mo, prod (t4g.small) ~$17/mo. Keeping dev
stopped except when actively working is the main lever.

## If you'd rather not run a second box

You can host dev locally instead — the repo already supports it
(`npm run dev` + the Docker Postgres in the original `compose.yml`). Then AWS only
ever runs prod, and "promotion" is just the prod launch above. Cheapest of all.
