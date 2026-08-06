# ---------------------------------------------------------------------------
# IAM Module
# Creates least-privilege service accounts for:
#   1. Application workload runtime (GKE/Cloud Run/Compute Engine)
#   2. CI/CD pipeline execution (Cloud Build)
# Grants custom-scoped project roles rather than broad Editor/Owner access.
# ---------------------------------------------------------------------------

resource "google_service_account" "workload" {
  project      = var.project_id
  account_id   = "${var.environment}-${var.app_name}-runtime"
  display_name = "${var.app_name} runtime SA (${var.environment})"
  description  = "Runtime identity for the ${var.app_name} application workload"
}

resource "google_project_iam_member" "workload_roles" {
  for_each = toset(var.workload_service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.workload.email}"
}

resource "google_service_account" "cicd" {
  project      = var.project_id
  account_id   = "${var.environment}-${var.app_name}-cicd"
  display_name = "${var.app_name} CI/CD SA (${var.environment})"
  description  = "Cloud Build execution identity for building & deploying ${var.app_name}"
}

resource "google_project_iam_member" "cicd_roles" {
  for_each = toset(var.cicd_service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cicd.email}"
}

# Allow the CI/CD SA to impersonate/act-as the workload SA when deploying
# (e.g. `gcloud run deploy --service-account`, GKE pod-level bindings).
resource "google_service_account_iam_member" "cicd_can_actas_workload" {
  service_account_id = google_service_account.workload.name
  role                = "roles/iam.serviceAccountUser"
  member              = "serviceAccount:${google_service_account.cicd.email}"
}

# Workload Identity binding: lets a Kubernetes Service Account impersonate
# the GCP workload service account without exporting key files.
resource "google_service_account_iam_member" "workload_identity_binding" {
  count               = var.enable_workload_identity ? 1 : 0
  service_account_id = google_service_account.workload.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[${var.gke_namespace_ksa}]"
}
