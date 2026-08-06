terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_TFSTATE_BUCKET-network-hub"
    prefix = "terraform/state/network-hub"
  }
}
