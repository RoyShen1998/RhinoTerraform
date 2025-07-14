terraform {
    required_version = ">= 1.0.0" # Ensure that the Terraform version is 1.0.0 or higher

    required_providers {
        aws = {
            source = "hashicorp/aws" # Specify the source of the AWS provider
            version = "~> 4.0"        # Use a version of the AWS provider that is compatible with version
        }
    }
}

provider "aws" {
    region = "ap-southeast-2"
}

resource "aws_s3_bucket" "angular_rhino_app" {
    bucket = "rhino-angular-bucket"

}

resource "aws_s3_bucket_website_configuration" "angular_rhino_siteConfiguration" {
    bucket = aws_s3_bucket.angular_rhino_app.id

    index_document {
        suffix = "index.html"
    }

    error_document {
        key = "index.html"
    }
}

resource "aws_s3_bucket_policy" "public_read" {
    depends_on = [aws_s3_bucket_public_access_block.unblock_public_policy]

    bucket = aws_s3_bucket.angular_rhino_app.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Sid       = "PublicReadGetObject"
                Effect    = "Allow"
                Principal = "*"
                Action    = "s3:GetObject"
                Resource  = "${aws_s3_bucket.angular_rhino_app.arn}/*"
            }
        ]
    })
}

resource "aws_s3_object" "rhino_built_angular_files" {
    for_each = fileset(var.rhino_angular_build_path, "**/*.*")

    bucket = aws_s3_bucket.angular_rhino_app.id
    key    = each.key
    source = "${var.rhino_angular_build_path}/${each.key}"
    etag = filemd5("${var.rhino_angular_build_path}/${each.key}")
    content_type = lookup({
        html = "text/html"
        css  = "text/css"
        js   = "application/javascript"
        json = "application/json"
        png  = "image/png"
        jpg  = "image/jpeg"
        svg  = "image/svg+xml"
    }, split(".", each.key)[length(split(".", each.key)) - 1], "application/octet-stream")
}

resource "aws_s3_bucket_public_access_block" "unblock_public_policy" {
    bucket                  = aws_s3_bucket.angular_rhino_app.id
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

output "website_url" {
    description = "Rhino app website endpoint"
    value = aws_s3_bucket_website_configuration.angular_rhino_siteConfiguration.website_endpoint
}


