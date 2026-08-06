terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_TFSTATE_BUCKET-dev"
    prefix = "terraform/state/dev"
  }
}
