# Cloud Resume Challenge

A serverless resume website on AWS, built with Terraform and deployed
via GitHub Actions CI/CD. Built as a hands-on project to learn AWS
fundamentals (static hosting, CDN, serverless compute, IaC, CI/CD,
security, and observability) end to end.

**Status:** 🚧 In progress — Phase 1 of 6 complete (static site
infrastructure). Built and tested on macOS 10.14 with AWS CLI v1
(pip-installed) and Terraform 1.9.8. Domain registered and DNS hosted
on Cloudflare (see architecture.md for why this differs from the
original Route53-only plan).

## Architecture

```
                    ┌─────────────┐
   Visitor ────────▶│  CloudFront │  (HTTPS via ACM, custom domain)
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  S3 Bucket   │  (private, static resume site)
                    └─────────────┘

                    ┌─────────────┐
   Browser JS ─────▶│ API Gateway │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐      ┌─────────────┐
                    │   Lambda     │─────▶│  DynamoDB    │
                    │  (Python)    │      │ (visit count)│
                    └─────────────┘      └─────────────┘
```

Full details in [`docs/architecture.md`](docs/architecture.md).

## Tech stack

- **Frontend:** static HTML/CSS/JS, served from S3 via CloudFront
- **Backend:** Python Lambda + API Gateway (visitor counter)
- **Database:** DynamoDB
- **IaC:** Terraform
- **CI/CD:** GitHub Actions (OIDC — no long-lived AWS keys in CI)
- **DNS/TLS:** Route53 + ACM (free public certs)
- **Observability:** CloudWatch dashboards, alarms, structured logs

## Cost

Designed to stay within AWS free tier except for the Route53 hosted
zone (~$0.50/month) and domain registration (~$10-15/year). See
[`docs/architecture.md`](docs/architecture.md) for the full cost
breakdown per service.

## Repo structure

```
cloud-resume-challenge/
├── docs/                    # architecture notes, troubleshooting log
├── frontend/                # static site source
├── backend/lambda/          # Python Lambda source + tests
├── terraform/
│   ├── bootstrap/           # one-time: creates TF state backend
│   └── modules/             # static-site, counter-api, observability
└── .github/workflows/       # CI/CD pipelines
```

## Build log (phases)

- [x] **Phase 0** — AWS account setup, security baseline, Terraform
      state backend. See [`terraform/bootstrap/README.md`](terraform/bootstrap/README.md).
- [x] **Phase 1** — Static site infrastructure (S3 + CloudFront + ACM +
      Cloudflare DNS). See [`terraform/README.md`](terraform/README.md).
- [ ] **Phase 2** — Visitor counter backend (DynamoDB + Lambda + API Gateway)
- [ ] **Phase 3** — Wire frontend to backend API
- [ ] **Phase 4** — CI/CD pipelines (GitHub Actions)
- [ ] **Phase 5** — Observability (CloudWatch dashboards + alarms)
- [ ] **Phase 6** — Final polish & write-up

## Troubleshooting

Real issues hit while building this are logged in
[`docs/troubleshooting.md`](docs/troubleshooting.md).

## Security notes

- Root account: MFA enabled, no root access keys
- Daily admin: dedicated IAM user with MFA (not root)
- CI/CD: GitHub Actions authenticates via OIDC, no static AWS keys stored in GitHub
- Terraform state: encrypted at rest, versioned, public access blocked
- (More added as each phase introduces new resources — see architecture.md)
