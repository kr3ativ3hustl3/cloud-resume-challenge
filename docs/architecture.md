# Architecture Notes

## Overview

This project follows the Cloud Resume Challenge pattern: a static
resume site backed by a serverless visitor counter, fully defined as
code and deployed through CI/CD.

## Design decisions & tradeoffs

### S3 + CloudFront, not S3 static website hosting alone
S3 website endpoints are HTTP-only and can't use a custom domain with
free HTTPS on their own. Fronting the bucket with CloudFront adds free
SSL (via ACM), a global CDN (faster loads), and lets the bucket itself
stay fully private. Tradeoff: one more moving part to configure and
one more thing that can go wrong (cache invalidation on deploy).

### DynamoDB, not RDS, for the visitor counter
The counter is a single item that needs an atomic increment. RDS would
mean paying for (or carefully managing free-tier limits on) an
always-on database instance for one number. DynamoDB is pay-per-request
with a generous permanent free tier, and `UpdateItem` with `ADD`
gives atomic increments without extra locking logic.

### Lambda, not a container/EC2, for the API
Traffic on a portfolio project is sporadic — near-zero most of the
time. Lambda charges per invocation with a large permanent free tier,
so idle time costs nothing. Tradeoff: cold starts add latency on the
first request after idle periods; acceptable for this use case.

### Terraform, not console clicks or CDK
Terraform is cloud-agnostic, widely used in industry, and the state
file plus plan/apply workflow gives you a reviewable diff of
infrastructure changes — a real, demonstrable skill. Tradeoff: steeper
learning curve than clicking in the console.

### GitHub Actions with OIDC, not IAM access keys, for CI/CD
Long-lived AWS access keys stored as GitHub secrets are a common real
-world breach vector if a repo or secret leaks. OIDC lets GitHub
Actions assume an IAM role with short-lived, auto-expiring credentials
scoped to that specific repo/workflow — no static keys anywhere.
Tradeoff: initial setup (IAM OIDC provider + trust policy) is more
involved than pasting two secrets.

### Cloudflare for domain registration + DNS, not Route53
Originally planned to register the domain and host DNS both in
Route53. Two real-world constraints changed this: (1) Route53 domain
registration blocks new/unverified AWS accounts as a fraud-prevention
measure, and (2) Cloudflare Registrar — used instead — locks a
registered domain to Cloudflare's own nameservers with no override.
Rather than fight either platform, DNS now lives entirely in
Cloudflare, managed via Terraform's Cloudflare provider alongside the
AWS provider in the same configuration. The CloudFront-facing records
and the ACM validation record are kept "DNS only" (not proxied through
Cloudflare's CDN) so there's a single CDN layer (CloudFront), not two
stacked on top of each other. Tradeoff: infrastructure now spans two
providers instead of one, which is slightly more moving parts to
reason about, but it's a realistic, common pattern (registrar and DNS
host frequently differ from the compute/hosting provider in real
companies) and demonstrates multi-provider Terraform, which is a
genuine plus for a portfolio.

### Origin Access Control (OAC), not Origin Access Identity (OAI)
AWS's older mechanism for letting CloudFront read a private S3 bucket
was OAI. AWS now recommends OAC instead — it supports SSE-KMS
encrypted buckets (OAI doesn't) and uses proper SigV4 signing. Since
this is a new project with no legacy dependency on OAI, there's no
reason to use the older approach.

### CloudFront PriceClass_100
CloudFront lets you choose which edge location tiers serve your
content. `PriceClass_100` covers North America and Europe only, at
the lowest cost. The higher tiers add edge locations in Asia, South
America, etc., at higher cost. For a personal portfolio site where
the audience is realistically recruiters and interviewers in a
handful of regions, the broader (pricier) tiers add cost without
meaningfully improving the experience for the people actually viewing
it.

### Custom error responses redirect 403/404 to index.html
A visitor hitting a broken or old link would otherwise see a raw S3
XML error page, which looks unpolished. Redirecting to the homepage
with a 200 status keeps the experience clean. Tradeoff: genuinely
missing pages won't show a distinct "404" signal to search engines —
acceptable for a small personal site with no meaningful SEO concerns.

### HTTP API (API Gateway v2), not REST API (v1)
API Gateway offers two distinct product types. The older REST API
type supports more features (request validation, usage plans, API
keys) but costs more and has more configuration surface. HTTP API is
newer, cheaper, and covers everything this project needs: one route,
Lambda proxy integration, and CORS. For a single-endpoint visitor
counter, the extra REST API features would be unused complexity.

### Page-load counter, not unique-visitor counter
This counts every page load, not distinct visitors — refreshing the
page increments it again. A true unique-visitor counter needs some
form of client identification (cookies, local storage, or IP-based
deduplication), which adds real complexity and, for cookies/tracking,
privacy considerations that aren't worth it for a portfolio site's
visitor counter. This tradeoff is intentional and worth mentioning if
asked in an interview — it shows awareness of the distinction, not
just a decision made by default.

### AWSLambdaBasicExecutionRole (managed policy) for logging, but a custom scoped policy for DynamoDB
These two IAM decisions look inconsistent at first glance but aren't.
The logging permissions (CreateLogGroup/CreateLogStream/PutLogEvents)
are identical for virtually every Lambda function, so using AWS's own
managed policy is the standard, low-maintenance choice. The DynamoDB
permission, by contrast, is specific to this function's actual job —
it's scoped to exactly one action (`UpdateItem`) on exactly one table,
which is what real least-privilege IAM looks like: broad, well-known
permissions can reasonably use managed policies, but anything
resource-specific should be scoped by hand.

### Hardcoded API endpoint in frontend JS, not a config file
The counter's API URL is written directly into `counter.js` rather
than injected from an environment variable or config file at build
time. For a single-environment personal project, adding a build step
or config-templating system just to avoid one hardcoded URL is more
complexity than it's worth. If this project ever needed multiple
environments (staging/prod), templating the URL in via the Phase 4
CI/CD pipeline would be the natural next step.

### Zip-based Lambda packaging via a manual shell script, not a Terraform provider
Both the `archive` and `null` Terraform provider plugins turned out to
require a newer OS version than this project's development machine
has, breaking outright rather than degrading gracefully. Rather than
keep hunting for a compatible provider version, packaging moved to a
plain shell script (`backend/lambda/build.sh`) using the `zip` command
already present on macOS/Linux. This adds one manual step before
`terraform apply` but removes two fragile binary dependencies, and
mirrors how real CI/CD pipelines separate a build step from a deploy
step — which Phase 4 formalizes properly with GitHub Actions.

### CI/CD deploys application code only, never runs terraform apply
GitHub Actions has narrow, explicit permissions — upload to one S3
bucket, invalidate one CloudFront distribution, update one Lambda
function's code. It cannot create, modify, or delete any other AWS
resource. This means a compromised or buggy workflow run has a small,
well-understood blast radius, rather than the ability to reshape the
whole account's infrastructure. Infrastructure changes remain a
manual, deliberate `terraform apply` run by a human. Tradeoff: this
means infrastructure and application code deploy through two different
paths, which is slightly less "everything as code" than a fully
GitOps-driven setup — a reasonable next evolution for a larger project,
but more machinery than a personal portfolio site needs.

### GitHub Actions OIDC, not long-lived IAM access keys
The alternative — storing an IAM user's access key/secret as GitHub
secrets — is a common real-world breach vector, since those
credentials are long-lived and static. OIDC lets GitHub Actions
request a short-lived token scoped to exactly this repo and branch,
with no static secret to leak in the first place.

## Cost breakdown (expected)

| Service | Free tier | Expected usage | Expected cost |
|---|---|---|---|
| S3 | 5GB storage, 20k GET/mo (12mo) | A few MB, low traffic | $0 |
| CloudFront | 1TB transfer/mo (forever) | Portfolio-level traffic | $0 |
| ACM | Free always | 1 certificate | $0 |
| Cloudflare DNS | Free plan | 1 zone, low query volume | $0 |
| Domain registration (Cloudflare) | Not free | 1 domain/yr, at-cost pricing | ~$10-12/yr |
| Lambda | 1M requests/mo (forever) | Low hundreds/mo | $0 |
| API Gateway | 1M calls/mo (12mo) | Low hundreds/mo | $0 |
| DynamoDB | 25GB + 25 WCU/RCU (forever) | 1 item | $0 |
| CloudWatch | 10 metrics, 5GB logs (forever) | Small dashboard | $0 |

**Bottom line:** roughly $10-12 once a year for domain renewal, $0
everything else at this traffic level.

## Security posture (running list, updated per phase)

- Phase 0: root MFA, no root keys, dedicated least-privilege-where-
  practical IAM user, Terraform state encrypted + versioned + private.
- Phase 1: S3 bucket fully private (no public access, no static
  website hosting endpoint) — only reachable through CloudFront via
  Origin Access Control scoped to this exact distribution's ARN.
  CloudFront enforces HTTPS (redirect-to-https) with TLS 1.2 minimum.
  Cloudflare API token scoped to a single zone with DNS-edit-only
  permission, stored only as a local environment variable, never
  committed to the repo.
- Phase 2: Lambda execution role scoped to exactly one DynamoDB action
  (`UpdateItem`) on exactly one table — cannot read, scan, delete, or
  touch any other table. CloudWatch log retention capped at 14 days
  rather than kept indefinitely. API Gateway CORS configuration
  restricts which origins may call the endpoint from a browser.
- Phase 4: GitHub Actions authenticates via OIDC with short-lived,
  auto-expiring tokens — no static AWS credentials stored anywhere in
  GitHub. The CI/CD IAM role is scoped to exactly three actions on
  three specific resources (this S3 bucket, this CloudFront
  distribution, this Lambda function) and can be assumed only from
  this exact repo's `main` branch — a compromised workflow run cannot
  touch any other AWS resource or run `terraform apply`.

## Observability posture (running list, updated per phase)

- (Added starting Phase 5: CloudWatch dashboard for Lambda
  invocations/errors/duration, API Gateway 4xx/5xx, budget alarm from
  Phase 0, log retention policy.)
