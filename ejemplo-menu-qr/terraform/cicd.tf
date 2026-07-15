# =============================================================================
#  cicd.tf — La cuenta de servicio que usa el pipeline de GitHub Actions.
#
#  En vez de crearla a mano con gcloud, la hace Terraform:
#    1) La cuenta de servicio (la identidad del pipeline).
#    2) Sus permisos: lo justo para entrar a la VM y desplegar.
#    3) Su llave (key.json), que después se carga como secret GCP_SA_KEY.
#
#  ⚠️ Ojo: la llave queda guardada en el estado de Terraform (terraform.tfstate).
#     Ese archivo pasa a ser sensible: no lo subas al repo ni lo compartas.
# =============================================================================

# 1) La cuenta de servicio del pipeline.
resource "google_service_account" "cicd" {
  account_id   = "${var.service_name}-cicd"
  display_name = "Cuenta del pipeline de GitHub"
}

# 2) Los permisos (mínimos) que necesita para desplegar en la VM:
#    - compute.instanceAdmin.v1 -> entrar por SSH y operar la VM
#    - iam.serviceAccountUser   -> hace falta porque la VM tiene su propia cuenta
resource "google_project_iam_member" "cicd" {
  for_each = toset([
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# 3) La llave (JSON) de la cuenta. Es la que va al secret GCP_SA_KEY de GitHub.
resource "google_service_account_key" "cicd" {
  service_account_id = google_service_account.cicd.name
}
