# ---------------------------------------------------------------------------
# Secret Manager Module
# Creates secret containers (and optional bootstrap versions) with
# fine-grained accessor bindings, instead of relying on broad project roles.
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "secret" {
  for_each  = var.secrets
  project   = var.project_id
  secret_id = "${var.environment}-${each.key}"

  labels = merge(
    { environment = var.environment, managed_by = "terraform" },
    each.value.labels
  )

  replication {
    dynamic "auto" {
      for_each = var.replication == "automatic" ? [1] : []
      content {}
    }
    dynamic "user_managed" {
      for_each = var.replication != "automatic" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = split(",", var.replication)
          content {
            location = replicas.value
          }
        }
      }
    }
  }
}

resource "google_secret_manager_secret_version" "initial" {
  for_each = {
    for k, v in var.secrets : k => v if v.initial_value != null
  }
  secret      = google_secret_manager_secret.secret[each.key].id
  secret_data = each.value.initial_value
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for pair in setproduct(keys(var.secrets), var.accessor_service_account_emails) :
    "${pair[0]}-${pair[1]}" => { secret = pair[0], sa = pair[1] }
  }
  project   = var.project_id
  secret_id = google_secret_manager_secret.secret[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa}"
}
