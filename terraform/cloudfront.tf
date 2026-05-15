# Origin Access Control — lets CloudFront sign requests to S3 so the
# bucket can stay private.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "tc-brand-prod-oac"
  description                       = "OAC for the TrailCount homepage S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "TrailCount homepage (trailcount.io apex + www)"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, CA, EU — cheapest tier; site is US-focused
  aliases             = [local.apex_domain, local.www_domain]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # CachingOptimized managed policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # SPA-style fallback isn't really needed for a 1-page site, but
  # returning index.html on 403/404 means typos like /about don't show
  # the raw S3 access-denied page.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name    = "tc-brand-prod-cf"
    Tenant  = "brand"
    Env     = "prod"
    Project = "trailcount-homepage"
  }
}
