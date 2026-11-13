terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Credentials are never stored in this repository. They come from your AWS CLI
# configuration (~/.aws) or the standard AWS_* environment variables.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

locals {
  # The backend and frontend live in their own repositories. By default they
  # are expected to be checked out next to this one.
  backend_path = coalesce(var.rhino_backend_path, "${path.module}/../backend")
  build_path   = coalesce(var.rhino_angular_build_path, "${path.module}/../frontend/dist/rhino-identifier/browser")

  # What this configuration relies on in the backend repository.
  api_source_dir = "${local.backend_path}/rhino_api"
  api_handler    = "index.lambda_handler"

  # The deployed site reads its API URL from this file when it starts. It is
  # generated here, so the frontend's development copy is not uploaded.
  runtime_config_file = "config.json"
}
