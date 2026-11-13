# The website: a private S3 bucket served through CloudFront.

locals {
  content_types = {
    html  = "text/html"
    css   = "text/css"
    js    = "application/javascript"
    json  = "application/json"
    map   = "application/json"
    txt   = "text/plain"
    png   = "image/png"
    jpg   = "image/jpeg"
    jpeg  = "image/jpeg"
    webp  = "image/webp"
    svg   = "image/svg+xml"
    ico   = "image/x-icon"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }

  site_files = setsubtract(fileset(local.build_path, "**"), [local.runtime_config_file])
}

resource "aws_s3_bucket" "angular_rhino_app" {
  bucket = var.bucket_name

  # The bucket only holds build output, so it is safe to throw away.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "angular_rhino_app" {
  bucket                  = aws_s3_bucket.angular_rhino_app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudfront_read" {
  depends_on = [aws_s3_bucket_public_access_block.angular_rhino_app]

  bucket = aws_s3_bucket.angular_rhino_app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudFrontReadGetObject"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.angular_rhino_app.arn}/*"
        Condition = {
          StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.angular_rhino_app.arn }
        }
      }
    ]
  })
}

resource "aws_s3_object" "rhino_built_angular_files" {
  for_each = local.site_files

  bucket       = aws_s3_bucket.angular_rhino_app.id
  key          = each.key
  source       = "${local.build_path}/${each.key}"
  etag         = filemd5("${local.build_path}/${each.key}")
  content_type = lookup(local.content_types, reverse(split(".", each.key))[0], "application/octet-stream")

  # Angular puts a content hash in its bundle names, so those can be cached
  # forever. Everything else (index.html) must be re-checked on every visit.
  cache_control = can(regex("-[A-Z0-9]{8}\\.(js|css)$", each.key)) ? "public, max-age=31536000, immutable" : "no-cache"
}

# The API URL is only known once the Lambda exists, so the app reads it from
# this file at startup instead of having it compiled in.
resource "aws_s3_object" "runtime_config" {
  bucket        = aws_s3_bucket.angular_rhino_app.id
  key           = local.runtime_config_file
  content       = jsonencode({ apiUrl = trimsuffix(aws_lambda_function_url.rhino_api.function_url, "/") })
  content_type  = "application/json"
  cache_control = "no-cache"

  lifecycle {
    precondition {
      condition     = fileexists("${local.build_path}/index.html")
      error_message = "No built frontend found in ${local.build_path}. Run `npm run build` in the frontend repository first, or set rhino_angular_build_path."
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_origin_access_control" "angular_rhino_app" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "angular_rhino_app" {
  enabled             = true
  comment             = "Rhino AI website"
  default_root_object = "index.html"

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.angular_rhino_app.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.angular_rhino_app.id
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
