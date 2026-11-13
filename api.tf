# The rhino API: one Lambda behind a public Function URL.

data "archive_file" "rhino_api" {
  type        = "zip"
  source_dir  = local.api_source_dir
  output_path = "${path.module}/.build/rhino_api.zip"
  excludes    = ["__pycache__"]
}

resource "aws_iam_role" "rhino_api" {
  name_prefix = "rhino-api-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rhino_api_logs" {
  role       = aws_iam_role.rhino_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "rhino_api_rekognition" {
  name = "rekognition"
  role = aws_iam_role.rhino_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectCustomLabels",
          "rekognition:DescribeProjects",
          "rekognition:DescribeProjectVersions",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "rhino_api" {
  name              = "/aws/lambda/rhino-api"
  retention_in_days = 30
}

resource "aws_lambda_function" "rhino_api" {
  function_name = "rhino-api"
  role          = aws_iam_role.rhino_api.arn

  runtime       = "python3.13"
  architectures = ["arm64"]
  handler       = local.api_handler
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.rhino_api.output_path
  source_code_hash = data.archive_file.rhino_api.output_base64sha256

  environment {
    variables = {
      REKOGNITION_MODEL_ARN = var.rekognition_model_arn
      MIN_CONFIDENCE        = tostring(var.min_confidence)
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.rhino_api.name
  }

  depends_on = [aws_iam_role_policy_attachment.rhino_api_logs]
}

resource "aws_lambda_function_url" "rhino_api" {
  function_name      = aws_lambda_function.rhino_api.function_name
  authorization_type = "NONE"

  # CORS is answered here, so the Lambda itself must not send CORS headers.
  cors {
    allow_origins = ["https://${aws_cloudfront_distribution.angular_rhino_app.domain_name}", "http://localhost:4200"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
    max_age       = 3600
  }
}

# A public Function URL needs both of these permissions to be callable.
resource "aws_lambda_permission" "rhino_api_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.rhino_api.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "rhino_api_invoke_via_url" {
  statement_id             = "AllowInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.rhino_api.function_name
  principal                = "*"
  invoked_via_function_url = true
}
