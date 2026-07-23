# Phase 1 — Static Site Infrastructure

Creates: private S3 bucket → CloudFront (HTTPS, custom domain) → ACM
certificate (DNS-validated via Cloudflare) → Cloudflare DNS record.

---

## 1. Set your domain

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and confirm `domain_name = "sunsetheard.dev"`
(or whatever you registered).

## 2. Set required environment variables

```bash
export AWS_PROFILE=cloud-resume
export CLOUDFLARE_API_TOKEN="paste-your-token-here"
```

Do this in your terminal session directly — **do not** write the
Cloudflare token into any file in this repo, even a gitignored one, if
you can avoid it. Environment variables in your shell session are
safer since they're never written to disk in the project folder.

## 3. Init, plan, apply

```bash
terraform init
```

This connects to the S3 backend created in Phase 0. You should see
`Terraform has been successfully initialized!`.

```bash
terraform plan
```

Review the plan. You should see roughly a dozen resources to add:
the S3 bucket and its sub-resources (encryption, versioning, public
access block, policy), the CloudFront Origin Access Control, the
CloudFront distribution itself, the ACM certificate + its validation,
and 2 Cloudflare DNS records (one for cert validation, one pointing
the domain at CloudFront). Nothing should show as "to change" or
"to destroy" on a first run.

```bash
terraform apply
```

Type `yes` to confirm.

**This step takes a while — expect 15-25 minutes.** Most of that time
is CloudFront actually provisioning your distribution globally; ACM
DNS validation is usually much faster (a few minutes). This is normal;
don't cancel it partway through.

## 4. Upload the placeholder site content

Terraform builds infrastructure, not content — uploading files is a
separate, deliberate step (and will be automated in Phase 4's CI/CD).
For now, do it manually to test:

```bash
terraform output s3_bucket_name
```

Copy that bucket name, then:

```bash
aws s3 sync ../frontend s3://<bucket-name-here> --profile cloud-resume
```

## 5. Test it

```bash
terraform output site_url
```

Open that URL in a browser. You should see the placeholder page over
HTTPS with a valid certificate (check for the padlock icon).

If it doesn't load yet, DNS may still be propagating — Cloudflare DNS
changes are usually fast (minutes) but can occasionally take longer.
You can test the CloudFront distribution directly in the meantime:

```bash
terraform output cloudfront_domain_name
```

Visiting `https://<that-value>` should work immediately, even before
your custom domain propagates, though the certificate warning may
appear there since the cert is issued for your domain, not the
`.cloudfront.net` one — that's expected and fine, it's just for testing.

---

## Verification checklist before moving to Phase 2

- [ ] `terraform apply` completed with no errors
- [ ] `https://sunsetheard.dev` (or your domain) loads the placeholder
      page over HTTPS with a valid, non-warning certificate
- [ ] Padlock icon shows in the browser address bar
- [ ] `terraform output` shows values for `s3_bucket_name`,
      `cloudfront_domain_name`, `cloudfront_distribution_id`

Once confirmed, we'll move to **Phase 2: the visitor counter backend**
(DynamoDB + Lambda + API Gateway).
