# ACM certificate for trailcount.io apex + www.trailcount.io. Must be
# in us-east-1 to be usable by CloudFront. Validation CNAMEs live in
# the workspace domain stack (../../terraform/domain/dns.tf), including
# the www SAN record in foreign_validation.

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

  # No validation_record_fqdns argument: ACM validates by polling DNS.
  # Records are in the Route 53 zone, not created by this stack.
  timeouts {
    create = "30m"
  }
}
