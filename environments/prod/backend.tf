terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_TFSTATE_BUCKET-prod"
    prefix = "terraform/state/prod"
  }
}
