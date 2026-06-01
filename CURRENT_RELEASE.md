# Current Setu Finance Release Sync

Last verified: June 1, 2026.

## Repositories

| Repository | Purpose | Verified branch | Verified commit |
| --- | --- | --- | --- |
| [`dlk710/setu-finance`](https://github.com/dlk710/setu-finance) | Product source code, backend, frontend, database migrations, and product documentation | `main` | `86a30c9` |
| [`dlk710/setu-finance-deploy-aws`](https://github.com/dlk710/setu-finance-deploy-aws) | AWS deployment scripts, Docker stack, Terraform, backup/restore runbooks, and environment templates | `main` | this repo's latest `main` |

## Current Dev Endpoint

- AWS dev endpoint: `https://18.218.196.158.sslip.io`
- AWS application name/tag: `setu-finance-dev`
- AWS region: `us-east-2`

## What "In Sync" Means

- Product GitHub `main` contains the latest app code and documentation.
- AWS deploy GitHub `main` contains the latest deployment scripts and runbooks.
- The AWS instance app checkout should be fast-forwarded to the product repo `main`.
- The AWS instance deploy checkout should be fast-forwarded to the deploy repo `main`.
- Docker Compose should be rebuilt with `./deploy.sh dev` after pulling product or deploy changes.

## Verification Commands

Run these on the AWS instance:

```bash
cd /opt/setu/app
git fetch origin main
git rev-parse --short HEAD
git rev-parse --short origin/main

cd /opt/setu/deploy
git fetch origin main
git rev-parse --short HEAD
git rev-parse --short origin/main

docker ps
curl -sk https://18.218.196.158.sslip.io/api/auth/status
```

Run these locally:

```bash
cd /Users/lohithdeshpande/Documents/Claude/Projects/FinanceProduct
git rev-parse --short HEAD
git ls-remote --heads origin main
npm run build

cd /Users/lohithdeshpande/Documents/Claude/Projects/setu-finance-deploy-aws
git rev-parse --short HEAD
git ls-remote --heads origin main
```
