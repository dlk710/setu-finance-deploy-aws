# Setu Finance — AWS account foundations (do these now)

These are the "no‑regret" foundations for your fresh account. They keep your
Free Tier credits intact and don't need to be redone when you scale.

## ⚠️ Credit‑preserving rules (read first)

Your ~$200 / 6‑month credits **vanish instantly** if you do any of these, which
also force‑upgrade you to the Paid Plan. **Avoid all of them until you're ready
to go paid:**

- [ ] Do **NOT** create or join an **AWS Organization**
- [ ] Do **NOT** set up **AWS Control Tower**
- [ ] Do **NOT** enable **IAM Identity Center (SSO)** — it turns on Organizations underneath

While on the free window, stay a **single account** and separate dev/prod by
*environment* (tags + separate stacks), not by separate accounts.

## 1. Secure the root account
- [ ] Enable **MFA** on the root user
- [ ] Delete any **root access keys** (there should be none)
- [ ] Stop using root for daily work

## 2. Identity for daily use
- [ ] Create one **IAM admin user** with console access + **MFA**
- [ ] Create **access keys** for that user only if you need CLI/Terraform locally
- [ ] (Defer IAM Identity Center to the paid/multi‑account phase)

## 3. Billing guardrails
- [ ] Create an **AWS Budget** with an email alert at a low threshold
      (the $1 budget trick — also earns one of your $20 credit activities)
- [ ] Turn on **Cost Explorer**
- [ ] Enable **Free Tier usage alerts** (Billing → Preferences)
- [ ] Give your IAM admin user **billing access** (account settings)
- [ ] Watch the classic surprise charges: unattached **Elastic IPs**,
      **NAT Gateways**, orphaned **EBS** volumes

## 4. Region
- [ ] Pick **one home region** (us‑east‑1 or us‑east‑2) and use it for everything

## 5. Tagging (activate now, painful to backfill)
- [ ] Tag everything with `Project`, `Environment`, `Owner`
- [ ] Activate those as **cost‑allocation tags** (Billing → Cost allocation tags)
      *(the Terraform in `terraform/` applies these automatically)*

## 6. Infrastructure as code
- [ ] Install **Terraform** locally
- [ ] Use the `terraform/` stack in this bundle to create the dev box in code
- [ ] Commit the Terraform to git (never commit `*.tfvars` with secrets or
      `*.tfstate` — they're gitignored)

## 7. Secrets
- [ ] Keep credentials in **SSM Parameter Store** (SecureString) — free
- [ ] Never commit real `.env*` files (the deploy bundle generates them on the box)

## 8. Light audit (optional, ~free)
- [ ] Note that **CloudTrail** logs management events for the last 90 days in the
      console by default — enough for now; a full trail to S3 comes later

---

## When you outgrow this (the paid / scaled phase)

Adopt these the moment the product is real — and accept that the first one ends
the free ride:

- AWS **Organizations** → separate dev / staging / prod accounts
- **IAM Identity Center** for team access
- **RDS / Aurora PostgreSQL (Multi‑AZ)** instead of Postgres‑on‑EC2
- **ECS Fargate / EKS + ALB + autoscaling** instead of one instance
- **S3 + CloudFront** for the static frontend (cheap, can adopt early)
- **SES** with production access + verified domain (DKIM/SPF/DMARC)
- Real **VPC** (public/private subnets, NAT), **WAF**, **Secrets Manager** rotation
- **CloudWatch** dashboards/alarms + centralized logs, **Cognito**, **CI/CD**

Because the app is 12‑factor (stateless API, config via env, Postgres external,
static frontend) and now lives in Terraform, each of these is a swap, not a rewrite.
