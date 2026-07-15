# =============================================================================
#  variables.tf — Los datos que cambian según quién use este código.
#
#  Una "variable" es un hueco que se completa desde afuera (en el archivo
#  terraform.tfvars). Así el mismo código sirve para distintos proyectos sin
#  tocar la lógica: solo cambian los valores.
# =============================================================================

variable "project_id" {
  description = "ID del proyecto de GCP donde se crea todo"
  type        = string
}

variable "region" {
  description = "Región donde vive la infraestructura (ej: São Paulo)"
  type        = string
  default     = "southamerica-east1"
}

variable "zone" {
  description = "Zona (dentro de la región) donde vive la VM"
  type        = string
  default     = "southamerica-east1-a"
}

variable "service_name" {
  description = "Prefijo para nombrar los recursos (así se reconocen fácil)"
  type        = string
  default     = "menu-food-truck"
}

variable "machine_type" {
  description = "Tamaño de la VM. e2-small es chico y barato, alcanza de sobra"
  type        = string
  default     = "e2-small"
}

variable "db_tier" {
  description = "Tamaño de la instancia Postgres. db-f1-micro es el más chico"
  type        = string
  default     = "db-f1-micro"
}

variable "db_user" {
  description = "Usuario de la base Postgres"
  type        = string
  default     = "menu"
}

variable "db_password" {
  description = "Contraseña de la base Postgres (¡secreto! va en terraform.tfvars)"
  type        = string
  sensitive   = true # Terraform la oculta en los mensajes de plan/apply
}
