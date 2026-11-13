# Rhino AI - infrastructure

Terraform configuration that deploys Rhino AI: upload a photo and identify rhinos with AWS Rekognition.

Rhino AI is split over three repositories:

| Repository | Contents |
| --- | --- |
| RhinoTerraform (this one) | Terraform: the API Lambda and its Function URL, a private S3 bucket and a CloudFront distribution for the website. No application code. |
| backend | The API Lambda source. |
| RhinoFrontend | The Angular web app. |

## Where the application code comes from

Terraform zips the Lambda from the backend checkout and uploads the **already built**
website from the frontend checkout. By default it expects both next to this repository:

```
<workspace>/
├── infra/       this repository
├── backend/
└── frontend/
```

If they are somewhere else, set `rhino_backend_path` and `rhino_angular_build_path` in `terraform.tfvars` (see below).

## Personal settings and credentials

Nothing personal is stored in this repository:

- **Settings** that are specific to you or your AWS account (bucket name, AWS profile, model ARN, local paths) go in `terraform.tfvars`, which is git-ignored. Copy the template and edit it:

  ```
  copy terraform.tfvars.example terraform.tfvars
  ```

- **AWS credentials** never go in any file here. Terraform reads them from your AWS CLI configuration (`aws configure`) or the `AWS_*` environment variables.
- **Terraform state** (`terraform.tfstate`) contains your account id and resource details and is git-ignored too.

What this configuration relies on in those repositories:

- backend: a `rhino_api/` directory whose `index.lambda_handler` is the Lambda handler, using only the standard library and boto3.
- frontend: `npm run build` writes the site to `dist/rhino-identifier/browser`, and the app reads its API URL from `config.json` (`{"apiUrl": "..."}`) at startup. Terraform generates that file.

## Deploy

```
cd ../frontend && npm ci && npm run build     # Terraform uploads this build
cd ../infra
terraform init
terraform plan
terraform apply
```

`terraform apply` prints `website_url` and `api_url`. After changing the frontend, build it
again and re-run `terraform apply`; after changing the backend, just re-run `terraform apply`.

### Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `bucket_name` | required | Website bucket. Bucket names are global, so pick your own. |
| `aws_region` | `ap-southeast-2` | Region to deploy to. |
| `aws_profile` | default credentials | Named AWS CLI profile to deploy with. |
| `rekognition_model_arn` | empty | Custom Labels model to use (see below). |
| `min_confidence` | `50` | Lowest label confidence the API reports. |
| `rhino_backend_path` | `../backend` | Backend checkout. |
| `rhino_angular_build_path` | `../frontend/dist/rhino-identifier/browser` | Built frontend. |

### Custom rhino model

By default the API uses stock Rekognition label detection, which can tell that a photo
contains a rhino. To identify species and gender, train a Rekognition Custom Labels model
(see the backend README for how its labels must be named), start it, and deploy with its
project version ARN set as `rekognition_model_arn` in `terraform.tfvars` (the ARN contains
your AWS account id, so keep it out of committed files).

A running Custom Labels model is billed by the hour, so stop it when you are not using it.

## Test

```
terraform fmt -check -recursive
terraform validate
terraform test
```

`terraform test` plans against a mocked AWS provider with stand-in backend and frontend
folders (`tests/fixtures`), so it needs no AWS credentials and creates nothing.

## Notes

- State is stored locally (`terraform.tfstate`, git-ignored). Keep that file: without it Terraform no longer knows what it deployed.
- The website bucket is private and only reachable through CloudFront over HTTPS. Earlier versions of this repository served it as a public S3 website.
- The API is a public Lambda Function URL with no authentication: anyone who has the URL can run Rekognition calls on this account. Add authentication or throttling before sharing it widely.
