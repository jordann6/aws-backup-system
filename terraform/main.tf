locals {
  project     = "backup"
  environment = var.environment
  region      = var.region

  common_tags = {
    project     = local.project
    environment = local.environment
    owner       = "jordann6"
    managed_by  = "terraform"
  }
}

# --- S3 Bucket ----------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "backups" {
  bucket = "${local.project}-${local.environment}-${random_string.suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Standard → Standard-IA → Glacier → Delete
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "backup-tiering"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.ia_tier_after_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.glacier_tier_after_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.delete_after_days
    }

    # Versions move to Glacier faster — they're recovery points, not primary access
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

# --- IAM Role for Lambda ------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "role-${local.project}-lambda-${local.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "lambda_s3_read" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      aws_s3_bucket.backups.arn,
      "${aws_s3_bucket.backups.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "lambda_s3_read" {
  name   = "policy-${local.project}-lambda-s3-read-${local.environment}"
  policy = data.aws_iam_policy_document.lambda_s3_read.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_read.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Lambda Function ----------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "backup_check" {
  function_name    = "lambda-${local.project}-confirmation-${local.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME      = aws_s3_bucket.backups.bucket
      ALERT_EMAIL      = var.alert_email
      SENDGRID_API_KEY = var.sendgrid_api_key
    }
  }

  tags = local.common_tags
}

# --- EventBridge Scheduler (daily at 08:00 UTC) -------------------------------

resource "aws_scheduler_schedule_group" "backup" {
  name = "${local.project}-${local.environment}"
  tags = local.common_tags
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "role-${local.project}-scheduler-${local.environment}"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "scheduler_invoke" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.backup_check.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name   = "invoke-${local.project}-lambda"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_invoke.json
}

resource "aws_scheduler_schedule" "daily" {
  name       = "daily-${local.project}-check"
  group_name = aws_scheduler_schedule_group.backup.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 8 * * ? *)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_lambda_function.backup_check.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
