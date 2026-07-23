variable "domain_name" {
  description = "Root domain the site will be served from (e.g. sunsetheard.dev). Must match a zone that already exists in Cloudflare."
  type        = string
}
