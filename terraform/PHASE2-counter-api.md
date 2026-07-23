# Phase 2 — Visitor Counter Backend

Creates: a DynamoDB table, a Python Lambda function that atomically
increments it, and an HTTP API (API Gateway) that exposes it publicly
with CORS configured for your domain.

---

## 1. (Optional but recommended) Run the Lambda tests locally first

This verifies the counter logic works before deploying it — catching
a bug here is much faster than catching it in AWS.

```bash
cd ~/projects/cloud-resume-challenge/backend/lambda
pip install -r tests/requirements.txt --break-system-packages
pytest tests/ -v
```

You should see 4 tests pass:
- first invocation returns count 1
- repeated invocations increment correctly
- CORS header is present and correct
- content type is JSON

## 2. Build the Lambda deployment package

Terraform doesn't build this automatically (see docs/troubleshooting.md
for why — some Terraform provider plugins turned out to be incompatible
with older macOS versions). Instead, run this manually before every
apply, and again any time `counter.py` changes:

```bash
cd ~/projects/cloud-resume-challenge/backend/lambda
./build.sh
```

This produces `terraform/modules/counter-api/counter.zip`.

## 3. Apply the Terraform

```bash
cd ~/projects/cloud-resume-challenge/terraform
```

Make sure your environment variables are still set (same shell
session, or re-export if you opened a new terminal):

```bash
export AWS_PROFILE=cloud-resume
export CLOUDFLARE_API_TOKEN="your-token"
```

```bash
terraform init
```

```bash
terraform plan
```

Review it — you should see new resources: the DynamoDB table, the
Lambda function + its IAM role + policies, the CloudWatch log group,
and the API Gateway (HTTP API) + its route, integration, stage, and
Lambda permission. Your existing Phase 1 resources should show no
changes.

```bash
terraform apply
```

This should be much faster than Phase 1 — a minute or two, not 15-25
minutes, since none of this needs global CDN propagation.

## 3. Test the API directly

```bash
terraform output counter_api_endpoint
```

Then call it:

```bash
curl https://<that-value>/count
```

Each call should return an incrementing count, e.g.:
```json
{"count": 1}
```
```json
{"count": 2}
```

## 4. Test CORS is configured correctly

```bash
curl -I -H "Origin: https://sunsetheard.dev" https://<api-endpoint>/count
```

Look for an `access-control-allow-origin` header in the response
matching your domain.

---

## Verification checklist before moving to Phase 3

- [ ] Lambda unit tests pass locally (4/4)
- [ ] `terraform apply` completed with no errors
- [ ] Calling `/count` via `curl` returns an incrementing JSON count
- [ ] The response includes a correct `access-control-allow-origin` header
- [ ] `terraform output counter_api_endpoint` shows a URL like
      `https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com`

Once confirmed, we'll move to **Phase 3: wiring the frontend's
JavaScript to actually call this API** and display the live count on
the resume page.
