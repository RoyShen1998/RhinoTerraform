# Values that are specific to you or your AWS account (bucket name, profile,
# model ARN, local paths) belong in terraform.tfvars, which is git-ignored.
# Copy terraform.tfvars.example to get started.

variable "aws_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region to deploy to."
}

variable "aws_profile" {
  type        = string
  default     = null
  description = "Named profile from your AWS CLI configuration to deploy with. Leave unset to use the default credentials."
}

variable "rhino_angular_build_path" {
  type        = string
  default     = null
  description = "Path to the built rhino Angular app (the folder containing index.html). Defaults to ../frontend/dist/rhino-identifier/browser."
}

variable "rhino_backend_path" {
  type        = string
  default     = null
  description = "Path to a checkout of the backend repository. Defaults to ../backend."
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket that stores the website files. Bucket names are global, so pick your own."
}

variable "rekognition_model_arn" {
  type        = string
  default     = ""
  description = "Rekognition Custom Labels project version ARN. Leave empty to use general Rekognition label detection."
}

variable "min_confidence" {
  type        = number
  default     = 50
  description = "Lowest label confidence (0-100) the API reports."

  validation {
    condition     = var.min_confidence >= 0 && var.min_confidence <= 100
    error_message = "min_confidence must be between 0 and 100."
  }
}
