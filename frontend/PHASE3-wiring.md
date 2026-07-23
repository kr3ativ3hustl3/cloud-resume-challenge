# Phase 3 — Wire Frontend to Backend API

No new infrastructure this phase — just deploying updated frontend
files and clearing the CDN cache so you actually see the change.

---

## What changed

- `frontend/js/counter.js` — calls the counter API on page load,
  updates the `#visit-count` element with the result
- `frontend/index.html` — now loads that script and starts with a
  neutral "Loading visitor count…" message

## 1. Deploy the updated files

```bash
cd ~/projects/cloud-resume-challenge/terraform
aws s3 sync ../frontend s3://sunsetheard-dev-site --profile cloud-resume
```

## 2. Invalidate the CloudFront cache

This is the step people usually forget, and the reason "it doesn't
look like anything changed" — CloudFront caches files for up to an
hour (`default_ttl = 3600` in the Terraform config). Uploading a new
`index.html` to S3 doesn't automatically clear what CloudFront has
already cached at its edge locations.

```bash
aws cloudfront create-invalidation \
  --distribution-id E3EH9YRH51URI \
  --paths "/*" \
  --profile cloud-resume
```

This takes 1-2 minutes to propagate. You'll get back an invalidation
ID; you generally don't need to check its status for a project this
size, but you can with:

```bash
aws cloudfront get-invalidation \
  --distribution-id E3EH9YRH51URI \
  --id <invalidation-id-from-above> \
  --profile cloud-resume
```

## 3. Test it in a browser

Open `https://sunsetheard.dev` and open the browser's **Developer
Tools → Network tab** before loading (or hard-refresh with the tools
already open: Cmd+Shift+R).

You should see:
- A request to `.../execute-api.us-east-1.amazonaws.com/count`
- The page showing "Visitor count: N" where N increments on each reload
- No CORS errors in the console

---

## Verification checklist before moving to Phase 4

- [ ] S3 sync completed with no errors
- [ ] CloudFront invalidation completed
- [ ] Browser shows an incrementing visitor count, not "unavailable"
- [ ] No errors in the browser console
- [ ] Reloading the page increments the count by exactly 1 each time

Once confirmed, we'll move to **Phase 4: CI/CD** — automating the sync
+ invalidation steps above (and the Lambda build/deploy) via GitHub
Actions, so you never have to run these commands by hand again after
a code change.
