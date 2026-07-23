# Phase 0 — AWS Account Setup & Terraform Bootstrap

Do these steps **in order**. Steps 1-4 are manual (console) because you
can't safely automate your own account's security setup with the same
account you're securing. Step 5 is Terraform.

---

## 1. Create your AWS account

1. Go to https://aws.amazon.com/free and click **Create an AWS Account**.
2. Use a real email you check often — this is where security alerts go.
3. Choose the **Basic support plan** (free).

You'll be asked for a credit card. This is normal — it's how AWS verifies
you're a real person, and it's also why Step 2 (budget alarm) matters.

---

## 2. Secure the root user (do this before anything else)

The root user is a super-admin with no restrictions — you should almost
never use it day-to-day.

1. Sign in as root (the email you signed up with).
2. Go to **IAM → Dashboard** and enable **MFA on the root user**
   (use an authenticator app like Google Authenticator or Authy — not SMS).
3. Do **not** create root access keys. If any exist, delete them.
   Root should only ever be used via the console, rarely.

**Why this matters for your portfolio:** "secured the root account with
MFA and avoided root access keys" is a genuine, correct AWS security
practice — mention it in your README/interview, it's a real signal.

---

## 3. Set a budget alarm (protects you from surprise bills)

1. Go to **Billing and Cost Management → Budgets → Create budget**.
2. Choose **Zero spend budget** (alerts you the moment you're charged
   anything beyond free tier) — simplest option for a learning account.
3. Alternatively, choose a **Cost budget** of $5/month with an alert
   at 80%.
4. Enter your email for the alert.

This costs nothing and is the single highest-value 5 minutes you'll
spend on this project.

---

## 4. Create an IAM identity for daily work (stop using root)

1. Go to **IAM → Users → Create user**.
2. Name: `terraform-admin`.
3. Attach policy: `AdministratorAccess` (see tradeoff note below).
4. Enable console access if you also want to browse the console as
   this user (optional, recommended).
5. Under **Security credentials**, enable **MFA** for this user too.
6. Create an **access key** (choose "Command Line Interface (CLI)" as
   the use case) — save the Access Key ID and Secret Access Key
   somewhere safe (a password manager, not a text file).

**Tradeoff — why `AdministratorAccess` and not least-privilege here:**
For a personal learning/portfolio account, scoping a custom least-
privilege policy for every resource type (S3, CloudFront, Lambda,
DynamoDB, IAM, Route53, ACM, CloudWatch...) adds a lot of friction for
very little real security benefit, since you're the only human with
access and the account holds no production data. In a real company
account, you would absolutely scope this down to only the services/
actions needed, and you'd use IAM Identity Center (SSO) with temporary
credentials instead of long-lived access keys. Mentioning this tradeoff
explicitly in an interview shows you understand the "why," not just
the "how" — which is exactly what recruiters are screening for.

Note: this user's long-lived keys are for **you, the human**, running
Terraform from your own machine. Later, in Phase 4, our GitHub Actions
CI/CD pipeline will use short-lived OIDC credentials instead — it will
NOT reuse these keys. Long-lived keys should never sit in CI secrets
if avoidable.

---

## 5. Install tooling locally

- **AWS CLI v2**: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- **Terraform** (>= 1.7): https://developer.hashicorp.com/terraform/install

Verify:
```bash
aws --version
terraform -version
```

Configure a named profile with the access key from Step 4:
```bash
aws configure --profile cloud-resume
# AWS Access Key ID: <paste>
# AWS Secret Access Key: <paste>
# Default region: us-east-1
# Default output format: json
```

Test it:
```bash
aws sts get-caller-identity --profile cloud-resume
```
You should see your account ID and the `terraform-admin` user ARN back.
If you get an error, see `docs/troubleshooting.md`.

From here on, every `terraform` and `aws` command in this repo assumes
you either exported `AWS_PROFILE=cloud-resume` or pass `--profile
cloud-resume` explicitly.

---

## 6. Apply the bootstrap Terraform (creates the state backend)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set a globally-unique state_bucket_name

export AWS_PROFILE=cloud-resume
terraform init
terraform plan     # review what it will create — 1 bucket, 1 table
terraform apply    # type 'yes' to confirm
```

This creates:
- 1 S3 bucket (versioned, encrypted, private) — holds Terraform state
- 1 DynamoDB table (pay-per-request) — holds Terraform state locks

Both are effectively free at this scale (well within free tier /
pennies per month).

**Save the output values** — `state_bucket_name` and `lock_table_name`
— you'll paste them into every other module's backend config in later
phases.

---

## Verification checklist before moving to Phase 1

- [ ] Root user has MFA enabled, no root access keys exist
- [ ] Budget alarm is created and you received a test/confirmation email
- [ ] `terraform-admin` IAM user exists with MFA enabled
- [ ] `aws sts get-caller-identity --profile cloud-resume` returns your identity
- [ ] `terraform apply` in `terraform/bootstrap/` succeeded
- [ ] You noted down `state_bucket_name` and `lock_table_name` from the outputs

Once all six are checked, reply and we'll move to **Phase 1: static site
infrastructure (S3 + CloudFront + ACM + Route53)**.
