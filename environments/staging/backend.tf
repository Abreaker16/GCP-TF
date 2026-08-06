terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_TFSTATE_BUCKET-staging"
    prefix = "terraform/state/staging"
  }
}
