# Remote state in S3 with DynamoDB-backed locking.
# Reuses the same bucket + lock table as the webapp stack.
# State lives at: s3://tc-tfstate-650244845886/homepage/terraform.tfstate
terraform {
  backend "s3" {
    bucket         = "tc-tfstate-650244845886"
    key            = "homepage/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tc-terraform-locks"
    encrypt        = true
  }
}
