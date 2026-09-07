# ─────────────────────────────────────────────────────────────────────────
# Public DNS is the workspace domain stack (../../terraform/domain/dns.tf),
# not this one. These outputs are the checklist of records that zone must
# contain for the homepage cert, CloudFront aliases, and inbound mail.
# Apex and www are A/AAAA aliases to CloudFront — no Squarespace 301.
# ─────────────────────────────────────────────────────────────────────────

output "cert_validation_records" {
  description = "DNS CNAMEs that must exist in terraform/domain so ACM can renew the trailcount.io cert"
  value = [
    for o in aws_acm_certificate.site.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ]
}

output "cname_target" {
  description = "CloudFront hostname for the Route 53 A/AAAA aliases on trailcount.io and www"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "Use for manual cache invalidations: aws cloudfront create-invalidation --distribution-id <id> --paths '/*'"
  value       = aws_cloudfront_distribution.site.id
}

output "s3_bucket" {
  description = "Bucket name for direct content uploads (aws s3 sync)"
  value       = aws_s3_bucket.site.bucket
}

# ── Email DNS records (live copies are in terraform/domain/dns.tf) ─────
output "ses_domain_verification_token" {
  description = "TXT _amazonses.trailcount.io — already in the domain stack"
  value       = aws_ses_domain_identity.trailcount.verification_token
}

output "ses_dkim_records" {
  description = "Three DKIM CNAMEs — already in the domain stack"
  value = [
    for t in aws_ses_domain_dkim.trailcount.dkim_tokens : {
      name  = "${t}._domainkey.${local.email_domain}."
      type  = "CNAME"
      value = "${t}.dkim.amazonses.com"
    }
  ]
}

output "ses_mx_record" {
  description = "MX for inbound SES — already in the domain stack"
  value = {
    name     = "@"
    type     = "MX"
    priority = 10
    value    = "inbound-smtp.us-east-1.amazonaws.com"
  }
}

output "ses_spf_update" {
  description = "SPF this stack would publish. Live DNS uses ~all (see terraform/domain/dns.tf); do not paste this -all value"
  value       = "v=spf1 include:amazonses.com -all"
}
