output "bucket_name" {
  value = aws_s3_bucket.backups.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.backup_check.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.backup_check.arn
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

output "scheduler_schedule_name" {
  value = aws_scheduler_schedule.daily.name
}
