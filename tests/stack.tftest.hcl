# Plan-level tests. The AWS provider is mocked, so these need no credentials
# and create nothing. Stand-in backend and frontend folders are used so the
# other repositories do not have to be checked out.

mock_provider "aws" {}

variables {
  bucket_name              = "test-rhino-site"
  rhino_backend_path       = "./tests/fixtures/backend"
  rhino_angular_build_path = "./tests/fixtures/site"
}

run "api" {
  command = plan

  assert {
    condition     = aws_lambda_function.rhino_api.runtime == "python3.13" && aws_lambda_function.rhino_api.handler == "index.lambda_handler"
    error_message = "The Lambda must run rhino_api/index.lambda_handler on Python 3.13."
  }

  assert {
    condition     = aws_lambda_function.rhino_api.environment[0].variables["REKOGNITION_MODEL_ARN"] == ""
    error_message = "Without rekognition_model_arn the API must run in general mode."
  }

  assert {
    condition     = aws_lambda_function_url.rhino_api.authorization_type == "NONE"
    error_message = "The Function URL is expected to be public."
  }

  assert {
    condition     = contains(aws_lambda_function_url.rhino_api.cors[0].allow_origins, "http://localhost:4200")
    error_message = "The frontend dev server must be an allowed CORS origin."
  }

  assert {
    condition     = aws_cloudwatch_log_group.rhino_api.retention_in_days == 30
    error_message = "API logs should expire after 30 days."
  }
}

run "custom_model" {
  command = plan

  variables {
    rekognition_model_arn = "arn:aws:rekognition:ap-southeast-2:123456789012:project/rhinos/version/v1/1700000000000"
  }

  assert {
    condition     = aws_lambda_function.rhino_api.environment[0].variables["REKOGNITION_MODEL_ARN"] == var.rekognition_model_arn
    error_message = "rekognition_model_arn must reach the Lambda."
  }
}

run "website" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.angular_rhino_app.block_public_acls,
      aws_s3_bucket_public_access_block.angular_rhino_app.block_public_policy,
      aws_s3_bucket_public_access_block.angular_rhino_app.ignore_public_acls,
      aws_s3_bucket_public_access_block.angular_rhino_app.restrict_public_buckets,
    ])
    error_message = "The website bucket must not be public."
  }

  assert {
    condition     = aws_cloudfront_distribution.angular_rhino_app.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "The website must be served over HTTPS."
  }

  assert {
    condition     = toset(keys(aws_s3_object.rhino_built_angular_files)) == toset(["index.html", "main-ABCD1234.js"])
    error_message = "All built files except config.json should be uploaded."
  }

  assert {
    condition     = aws_s3_object.rhino_built_angular_files["index.html"].content_type == "text/html" && aws_s3_object.rhino_built_angular_files["index.html"].cache_control == "no-cache"
    error_message = "index.html must be served as HTML and never cached."
  }

  assert {
    condition     = aws_s3_object.rhino_built_angular_files["main-ABCD1234.js"].cache_control == "public, max-age=31536000, immutable"
    error_message = "Hashed bundles should be cached long-term."
  }

  assert {
    condition     = aws_s3_object.runtime_config.key == "config.json" && aws_s3_object.runtime_config.cache_control == "no-cache"
    error_message = "config.json must be generated and never cached."
  }
}

run "missing_frontend_build" {
  command = plan

  variables {
    rhino_angular_build_path = "./tests/fixtures/backend"
  }

  expect_failures = [aws_s3_object.runtime_config]
}
