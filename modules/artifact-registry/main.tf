# ---------------------------------------------------------------------------
# Artifact Registry Module
# Central container/artifact repository with tag immutability and a
# cleanup policy to control storage cost growth.
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.environment}-${var.app_name}"
  description   = "Artifact repository for ${var.app_name} (${var.environment})"
  format        = var.format

  docker_config {
    immutable_tags = var.immutable_tags
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.cleanup_policy_keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state = "UNTAGGED"
      older_than = "1209600s" # 14 days
    }
  }
}
