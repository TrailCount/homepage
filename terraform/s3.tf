# Private S3 bucket for the static homepage. CloudFront reaches it via
# an Origin Access Control (sigv4-signed requests). The bucket is NOT
# public — only CloudFront can read it.

resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name    = local.bucket_name
    Tenant  = "brand"
    Env     = "prod"
    Project = "trailcount-homepage"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policy granting CloudFront (via OAC) read access. The policy
# uses a conditional check on the CloudFront distribution ARN so only
# this specific distribution can read from the bucket.
resource "aws_s3_bucket_policy" "site_cloudfront_read" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}

# Sync the homepage content into the bucket on every apply. Trigger is a
# hash of the files we want deployed, so terraform notices when content
# changes. Same pattern as the webapp's null_resource.deploy_react_app.
resource "null_resource" "deploy_homepage" {
  triggers = {
    content_hash = sha256(join("", [
      for f in sort([
        "index.html",
        "favicon.ico",
        "trailcount-icon.svg",
        "trailcount-logo-primary.svg",
      ]) : filemd5("${path.module}/../${f}")
    ]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 sync ${path.module}/.. s3://${aws_s3_bucket.site.bucket} \
        --exclude '*' \
        --include 'index.html' \
        --include 'favicon.ico' \
        --include 'trailcount-icon.svg' \
        --include 'trailcount-logo-primary.svg' \
        --delete
    EOT
  }

  depends_on = [
    aws_s3_bucket.site,
    aws_s3_bucket_policy.site_cloudfront_read,
  ]
}

# Invalidate CloudFront after content sync so edge caches refresh.
resource "null_resource" "invalidate_cloudfront" {
  triggers = {
    content_hash = null_resource.deploy_homepage.triggers.content_hash
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.site.id} --paths '/*'"
  }

  depends_on = [null_resource.deploy_homepage]
}
