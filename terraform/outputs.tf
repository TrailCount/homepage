# ─────────────────────────────────────────────────────────────────────────
# Two-wave Squarespace DNS dance:
#
# Wave 1 (cert validation): the first `terraform apply` will pause at
#   aws_acm_certificate_validation. In a separate terminal, run:
#       terraform output -json cert_validation_records
#   Take the CNAMEs and add them to Squarespace DNS for trailcount.io.
#   ACM polls, validates within ~5 min, apply resumes and creates
#   CloudFront.
#
# Wave 2 (traffic routing): after apply completes, add user-facing DNS
#   records at Squarespace:
#       www.trailcount.io  CNAME  ->  <cname_target>
#       trailcount.io      ALIAS  ->  <cname_target>     (apex)
#   Squarespace doesn't natively support ALIAS/ANAME for external
#   targets. Recommended apex handling:
#     - Use Squarespace's "Domain Forwarding" feature to forward
#       trailcount.io -> https://www.trailcount.io  (301 redirect)
#     - That keeps the SSL cert validation happy (cert covers apex
#       too) and the canonical URL becomes www.trailcount.io.
# ─────────────────────────────────────────────────────────────────────────

output "cert_validation_records" {
  description = "DNS CNAMEs to add to Squarespace so ACM can validate the trailcount.io cert"
  value = [
    for o in aws_acm_certificate.site.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ]
}

output "cname_target" {
  description = "Point trailcount.io and www.trailcount.io at this CloudFront hostname (CNAME for www, forwarding for apex)"
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

# ── Email DNS records to add at Squarespace ─────────────────────────────
output "ses_domain_verification_token" {
  description = "Add this as TXT _amazonses.trailcount.io at Squarespace to prove domain ownership to SES"
  value       = aws_ses_domain_identity.trailcount.verification_token
}

output "ses_dkim_records" {
  description = "Three CNAMEs at Squarespace so SES can sign outbound mail with DKIM"
  value = [
    for t in aws_ses_domain_dkim.trailcount.dkim_tokens : {
      name  = "${t}._domainkey.${local.email_domain}."
      type  = "CNAME"
      value = "${t}.dkim.amazonses.com"
    }
  ]
}

output "ses_mx_record" {
  description = "Add this MX record at Squarespace so SES can receive incoming mail for the domain"
  value = {
    name     = "@"
    type     = "MX"
    priority = 10
    value    = "inbound-smtp.us-east-1.amazonaws.com"
  }
}

output "ses_spf_update" {
  description = "Update the existing TXT @ SPF record from 'v=spf1 -all' to this value so SES is authorized to send"
  value       = "v=spf1 include:amazonses.com -all"
}
