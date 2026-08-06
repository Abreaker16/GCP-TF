# ---------------------------------------------------------------------------
# Storage Module
# Provisions application buckets with uniform bucket-level access,
# versioning, and lifecycle rules to control cost.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "bucket" {
  for_each = var.buckets

  project                     = var.project_id
  name                        = "${var.project_id}-${var.environment}-${var.app_name}-${each.key}"
  location                    = coalesce(each.value.location, var.region)
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  public_access_prevention    = each.value.public_access_prevention
  force_destroy               = false

  versioning {
    enabled = each.value.versioning
  }

  lifecycle_rule {
    condition {
      age = each.value.lifecycle_age_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}
