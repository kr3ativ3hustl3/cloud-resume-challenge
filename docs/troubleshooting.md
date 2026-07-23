# Troubleshooting Log

This doc grows with each phase. Format: symptom → cause → fix.
Keeping this is itself a portfolio signal — it shows real debugging,
not just a copy-pasted tutorial.

---

## Phase 0 — Account & Bootstrap

### `aws sts get-caller-identity` returns "Unable to locate credentials"
**Cause:** the `--profile` flag wasn't used, or `aws configure` was run
without `--profile cloud-resume`, so it went into the `default` profile
instead.
**Fix:** re-run `aws configure --profile cloud-resume`, or set
`export AWS_PROFILE=cloud-resume` in your shell.

### `terraform init` fails with a provider download error
**Cause:** usually a network/proxy issue, or an old Terraform version
that doesn't understand the `~> 5.0` provider constraint syntax.
**Fix:** confirm `terraform -version` is >= 1.7. If behind a corporate
proxy, set `HTTPS_PROXY`.

### `Error creating S3 bucket: BucketAlreadyExists`
**Cause:** S3 bucket names are globally unique across *all* AWS
accounts, not just yours. Someone else already has that name.
**Fix:** change `state_bucket_name` in `terraform.tfvars` to something
more unique (add random digits) and re-run `terraform apply`.

### `AccessDenied` when running `terraform apply`
**Cause:** the IAM user's policy doesn't allow the action, or MFA is
required but the CLI session isn't MFA-authenticated (if you set up an
MFA-enforcing policy).
**Fix:** confirm `AdministratorAccess` is attached to `terraform-admin`
in IAM → Users → terraform-admin → Permissions.

### macOS: `aws --version` fails with blake2b/blake2s hashlib errors and `_awscrt.abi3.so` symbol not found
**Cause:** the installed AWS CLI v2 build doesn't match your Mac's
chip architecture (Intel vs Apple Silicon), or a previous install was
corrupted. The native `awscrt` library was built for a different
macOS/CPU combination than what you're running.
**Fix:**
```bash
sudo rm -rf /usr/local/aws-cli
sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer
brew install awscli   # or use the official .pkg installer
aws --version
```

### macOS: `terraform: command not found`
**Cause:** Terraform was never installed, or installed without being
placed on your `PATH`.
**Fix:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version
```
If you don't use Homebrew, download the correct zip (check Intel vs
Apple Silicon under Apple menu → About This Mac) from
releases.hashicorp.com/terraform, unzip, and move the binary to
`/usr/local/bin/`.

### macOS 10.14 (Mojave) or older: AWS CLI v2 crashes on every command
**Cause:** AWS CLI v2 requires macOS 10.15 (Catalina) or later — its
bundled `awscrt` native library won't run on older macOS, no matter
how many times you reinstall it. The blake2b/blake2s hashlib errors
and the `_sec_protocol_options_set_min_tls_protocol_version` symbol
error are both symptoms of this same root cause.
**Fix:** install AWS CLI **v1** instead via pip, which is pure Python
and has no OS-version floor:
```bash
python3 -m pip install --user awscli
echo 'export PATH="$HOME/Library/Python/3.12/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
aws --version
```
(Adjust the `3.12` in the path to match your `python3 --version`.)

### `terraform.tfvars` ends up with a duplicate variable
**Cause:** editing the `.example` file's placeholder value by appending
a new line in `nano` instead of replacing the existing line — Terraform
sees two `state_bucket_name = ...` lines and errors.
**Fix:** open the file, delete the old placeholder line entirely
(`Ctrl+K` in nano), leaving only one line per variable.

### `InvalidClientTokenId` or `SignatureDoesNotMatch` from `aws sts get-caller-identity`
**Cause:** either the wrong value was pasted into `aws configure`
(e.g. the IAM *username* instead of the Access Key ID — a real key
always starts with `AKIA`), or the Secret Access Key got truncated
during copy/paste (a real secret key is always exactly 40 characters).
**Fix:** in IAM → Users → *your-user* → Security credentials, delete
the bad key, create a new one, and carefully copy the full Access Key
ID and Secret Access Key (use "Show" or download the CSV rather than
retyping). Re-run `aws configure --profile <name>`.

**Security note:** if a real access key/secret ever gets pasted
somewhere it shouldn't (a chat, a public repo, a shared doc), treat it
as compromised and rotate it immediately — deactivate and delete the
old key in IAM and create a fresh one. This is standard practice, not
an overreaction.

### Route53 domain registration fails: "not available on free tier" / access denied
**Cause:** Amazon Registrar (Route53 Domains) applies fraud-prevention
checks that new AWS accounts frequently fail, and it explicitly won't
register a domain using free-tier-only payment status — it requires a
settled, verified real payment method, and sometimes a manual AWS
Support review that can take days. This is a known, common experience
for brand-new accounts and is unrelated to the domain name itself.
**Fix:** don't fight it — register the domain through a normal
registrar instead (we used **Cloudflare Registrar**, at-cost pricing,
no markup), then create a **Route53 public hosted zone** for the same
domain (this part has no such restriction, since it's DNS hosting, not
registration), and update the domain's nameservers at the registrar to
point to the 4 NS values Route53 provides. This is a completely normal,
common architecture — registrar and DNS host don't have to be the same
provider.

### Cloudflare Registrar won't let you point to Route53 (or any external) nameservers
**Cause:** this isn't a bug or missing setting — Cloudflare Registrar
requires domains it registers to use Cloudflare's own nameservers,
full stop. There is no toggle to point a Cloudflare-registered domain
at AWS Route53 or any other DNS provider.
**Fix:** don't fight the platform — use Cloudflare as the DNS host too,
not just the registrar. Manage DNS records (including the CloudFront
alias and the ACM certificate validation CNAME) directly in Cloudflare
via Terraform's Cloudflare provider, in the same Terraform run as the
AWS resources. Keep those specific records set to "DNS only" (grey
cloud, not proxied) so traffic goes straight to CloudFront rather than
being double-proxied through Cloudflare's CDN on top of AWS's — avoids
unnecessary complexity and potential TLS handshake issues.

---

## Phase 1 — Static Site Infrastructure

### `terraform apply` seems to hang for a long time
**Cause:** not actually stuck — CloudFront distributions genuinely
take 15-25 minutes to deploy globally on first creation. Terraform is
correctly waiting for AWS to report the distribution as fully
deployed before finishing.
**Fix:** just wait. If it's been over ~40 minutes with no progress
messages at all, then check your terminal/network connection, but
don't cancel a normal in-progress apply.

### ACM certificate stuck in "Pending validation"
**Cause:** either the Cloudflare DNS validation record hasn't
propagated yet, or it was accidentally created as "proxied" (orange
cloud) instead of "DNS only" (grey cloud) — a proxied validation
record can prevent ACM from seeing it correctly.
**Fix:** in the Cloudflare dashboard, check the DNS record Terraform
created for certificate validation and confirm it's grey-clouded
(DNS only). Give it a few more minutes; ACM typically validates within
5-10 minutes of a correct, unproxied record existing.

### Site loads over the `.cloudfront.net` domain but not the custom domain
**Cause:** almost always DNS propagation delay for the Cloudflare
CNAME record pointing your domain at CloudFront.
**Fix:** check propagation with a public tool (e.g. whatsmydns.net) or
wait — Cloudflare DNS changes are typically fast (minutes) but can
occasionally take longer.

### Browser shows a certificate warning
**Cause:** you're likely visiting the raw `.cloudfront.net` URL rather
than your custom domain — the ACM certificate is issued specifically
for your domain, not for the CloudFront-assigned one.
**Fix:** this is expected when testing via the CloudFront URL directly;
visit your actual domain instead once DNS has propagated.

---

*(Phases 2-6 troubleshooting entries will be added as we build them.)*
