# ────────────────────────────────────────────────────────────────────────
# Email forwarding for contact@trailcount.io → craigmcg.acc@gmail.com
#
# Architecture:
#   sender → SES inbound (MX) → S3 → S3 trigger → Lambda → SES outbound
#
# Two DNS waves are needed at Squarespace, similar to the cert validation
# dance from the homepage hosting setup:
#
# Wave 1 (domain verification + DKIM, done before email starts flowing):
#   - TXT  _amazonses     ← from `ses_domain_verification_token` output
#   - 3 × CNAME <token>._domainkey  ← from `ses_dkim_tokens` output
#   - SPF: update the existing v=spf1 -all TXT @ to include SES sending
#       v=spf1 include:amazonses.com -all
#
# Wave 2 (inbound MX, done once verification is confirmed):
#   - MX  @  10  inbound-smtp.us-east-1.amazonaws.com
#
# Plus one manual SES action: confirm the FORWARD_TO Gmail address from
# the verification link AWS sends. Required while SES is in sandbox mode.
# ────────────────────────────────────────────────────────────────────────

locals {
  email_domain = local.apex_domain # trailcount.io
  forward_from = "forwarder@${local.apex_domain}"
  forward_to   = "craigmcg.acc@gmail.com"
}

# ── SES domain identity ─────────────────────────────────────────────────
resource "aws_ses_domain_identity" "trailcount" {
  domain = local.email_domain
}

resource "aws_ses_domain_dkim" "trailcount" {
  domain = aws_ses_domain_identity.trailcount.domain
}

# ── Gmail recipient (sandbox-mode verification) ─────────────────────────
# Until SES is moved out of sandbox via a support request, we can only
# send to verified addresses. Verify the Gmail. AWS will send a
# confirmation link to it; until clicked, sends will fail.
resource "aws_ses_email_identity" "forward_to" {
  email = local.forward_to
}

# ── S3 bucket for incoming raw email ────────────────────────────────────
resource "aws_s3_bucket" "incoming_email" {
  bucket        = "tc-brand-prod-email-incoming"
  force_destroy = true

  tags = {
    Name    = "tc-brand-prod-email-incoming"
    Tenant  = "brand"
    Env     = "prod"
    Project = "trailcount-email"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "incoming_email" {
  bucket = aws_s3_bucket.incoming_email.id

  rule {
    id     = "expire-old-mail"
    status = "Enabled"

    filter {}

    # Forwarded emails are ephemeral; once Lambda processes them, the
    # raw copy in S3 is just an audit trail. 30 days is plenty.
    expiration {
      days = 30
    }
  }
}

# Allow SES to write to the bucket
resource "aws_s3_bucket_policy" "incoming_email_ses_write" {
  bucket = aws_s3_bucket.incoming_email.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPuts"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.incoming_email.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# ── SES receipt rule set ─────────────────────────────────────────────────
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "tc-brand-prod-rules"
}

# Only one rule set can be active in an account at a time. Activate ours.
resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}

resource "aws_ses_receipt_rule" "contact" {
  name          = "tc-brand-prod-contact-forward"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = ["contact@${local.email_domain}"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.incoming_email.id
    position    = 1
  }

  depends_on = [
    aws_s3_bucket_policy.incoming_email_ses_write,
    aws_ses_domain_identity.trailcount,
  ]
}
