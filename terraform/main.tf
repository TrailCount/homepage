terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudFront + ACM-for-CloudFront both require us-east-1. The homepage
# bucket itself lives in us-east-1 too for simplicity.
provider "aws" {
  region = "us-east-1"
}

locals {
  apex_domain     = "trailcount.io"
  www_domain      = "www.trailcount.io"
  bucket_name     = "tc-brand-prod-site"
  # Match the existing tenant-stack naming convention (tc-<tenant>-<env>-)
  # so this slots into the same mental model as adk-* / demo-* stacks.
}
