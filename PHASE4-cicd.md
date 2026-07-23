# Phase 4 — CI/CD with GitHub Actions

Sets up automatic deployment on every push to `main`: frontend changes
sync to S3 + invalidate CloudFront; backend changes run tests, then
update the Lambda function's code. Infrastructure changes (anything
in `terraform/`) still require running `terraform apply` by hand —
CI/CD only ever deploys application code, never touches infrastructure.

---

## 1. Apply the Terraform (creates the OIDC trust + IAM role)

```bash
cd ~/projects/cloud-resume-challenge/terraform
```

Add your GitHub repo to `terraform.tfvars`:

```bash
echo 'github_repo = "kr3ativ3hustl3/cloud-resume-challenge"' >> terraform.tfvars
```

```bash
export AWS_PROFILE=cloud-resume
export CLOUDFLARE_API_TOKEN="your-token"
terraform init
terraform plan
```

Review it — you should see new resources: an OIDC identity provider,
an IAM role scoped to your repo's `main` branch, and its deploy
policy. Nothing from Phases 1-2 should change.

```bash
terraform apply
```

**If this fails with "OpenIDConnectProvider already exists":** your
AWS account already has a GitHub OIDC provider set up from something
else. See docs/troubleshooting.md for the fix (it's a quick one —
reference the existing provider instead of creating a new one).

```bash
terraform output github_actions_role_arn
```

Copy that ARN — you'll paste it into a GitHub secret next.

## 2. Add GitHub repository secrets

Go to your repo on GitHub → **Settings → Secrets and variables →
Actions → New repository secret**. Add these four:

| Secret name | Value | Where to get it |
|---|---|---|
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | the ARN from step 1 | `terraform output github_actions_role_arn` |
| `SITE_BUCKET_NAME` | your S3 bucket name | `terraform output s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | your distribution ID | `terraform output cloudfront_distribution_id` |
| `LAMBDA_FUNCTION_NAME` | your Lambda's name | `terraform output counter_lambda_function_name` |

None of these four values are secret in the sensitive sense (they're
all just resource identifiers, not credentials) — they're stored as
secrets purely so they're not hardcoded in the workflow YAML, making
it easy to reuse across environments later if needed.

## 3. Commit and push the workflow files

```bash
cd ~/projects/cloud-resume-challenge
git add .github terraform
git commit -m "Add CI/CD: GitHub Actions with OIDC"
git push
```

Since neither commit touches `frontend/` or `backend/` specifically,
this push won't trigger either workflow yet — that's expected. The
workflows only fire on changes to those specific folders (see the
`paths:` filters in each YAML file).

## 4. Test it

Make a small, harmless change to trigger a deploy — e.g. edit the
`<h1>` text in `frontend/index.html`:

```bash
git add frontend/index.html
git commit -m "Test CI/CD frontend deploy"
git push
```

Go to your repo on GitHub → **Actions tab**. You should see "Deploy
Frontend" running. Click into it to watch the steps execute live.
Once it finishes, hard-refresh `https://sunsetheard.dev` and confirm
your change is live — no manual `aws s3 sync` or cache invalidation
needed this time.

Repeat with a small backend change (e.g. a comment in `counter.py`) to
test the "Deploy Backend" workflow — watch it run the unit tests
first, then update the Lambda.

---

## Verification checklist before moving to Phase 5

- [ ] `terraform apply` succeeded, OIDC provider + IAM role exist
- [ ] All 4 GitHub secrets are set
- [ ] A frontend change triggers "Deploy Frontend" and shows up live
      on the site without any manual commands
- [ ] A backend change triggers "Deploy Backend", runs tests, and
      updates the Lambda
- [ ] Pushing a change to `docs/` or `README.md` alone does NOT
      trigger either workflow (confirms the `paths:` filters work)

Once confirmed, we'll move to **Phase 5: Observability** — a
CloudWatch dashboard and alarms so you can see traffic, errors, and
costs at a glance, and get notified if something breaks.
