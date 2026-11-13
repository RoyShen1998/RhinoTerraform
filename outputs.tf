output "website_url" {
  description = "Rhino app website endpoint"
  value       = "https://${aws_cloudfront_distribution.angular_rhino_app.domain_name}"
}

output "api_url" {
  description = "Rhino API endpoint (Lambda Function URL)"
  value       = aws_lambda_function_url.rhino_api.function_url
}
