# ACM certificate for trailcount.io apex + www.trailcount.io. Must be
# in us-east-1 to be usable by CloudFront. Validated via DNS CNAMEs
# that go in Squarespace's DNS panel — see the terraform outputs in
# outputs.tf for the records to add (two-wave dance: first apply pauses
# at aws_acm_certificate_validation while you paste the CNAMEs into
# Squarespace; ACM polls DNS, validates, apply resumes).

resource "aws_acm_certificate" "site" {
  domain_name               = local.apex_domain
  subject_alternative_names = [local.www_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "tc-brand-prod-cert"
    Tenant  = "brand"
    Env     = "prod"
    Project = "trailcount-homepage"
  }
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn

  # No validation_record_fqdns argument: ACM validates by polling DNS,
  # which works for the externally-managed Squarespace zone as long as
  # the user adds the CNAMEs (see outputs).
  timeouts {
    create = "30m"
  }
}
