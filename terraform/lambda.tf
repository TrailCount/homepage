# ── Lambda forwarder ────────────────────────────────────────────────────
# Triggered by S3 object-created events on the incoming-email bucket.
# Forwards each message to FORWARD_TO via SES SendRawEmail.

data "archive_file" "forwarder" {
  type        = "zip"
  source_file = "${path.module}/lambda/forwarder.py"
  output_path = "${path.module}/lambda/forwarder.zip"
}

resource "aws_iam_role" "forwarder" {
  name = "tc-brand-prod-email-forwarder"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "forwarder_basic" {
  role       = aws_iam_role.forwarder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "forwarder" {
  name = "tc-brand-prod-email-forwarder-inline"
  role = aws_iam_role.forwarder.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.incoming_email.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendRawEmail", "ses:SendEmail"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "forwarder" {
  function_name    = "tc-brand-prod-email-forwarder"
  role             = aws_iam_role.forwarder.arn
  handler          = "forwarder.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.forwarder.output_path
  source_code_hash = data.archive_file.forwarder.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      INCOMING_BUCKET = aws_s3_bucket.incoming_email.id
      FORWARD_TO      = local.forward_to
      FORWARD_FROM    = "TrailCount <${local.forward_from}>"
    }
  }
}

# Allow S3 to invoke the Lambda on object-created events.
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.incoming_email.arn
}

resource "aws_s3_bucket_notification" "incoming_email" {
  bucket = aws_s3_bucket.incoming_email.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.forwarder.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
