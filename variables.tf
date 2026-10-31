# Authentification Azure
variable "subscription_id" {
  type        = string
  description = "ID de la souscription Azure cible"
}

variable "client_id" {
  type        = string
  description = "App ID du Service Principal"
}

variable "client_secret" {
  type        = string
  description = "Secret d'authentification du Service Principal"
  sensitive   = true
}

variable "tenant_id" {
  type        = string
  description = "ID du tenant Entra ID"
}

# --- Parametrage demandee ---

variable "azure_region" {
  type        = string
  description = "Region de deploiement Azure"
  default     = "canadaeast"
}

variable "resource_prefix" {
  type        = string
  description = "Prefixe utilise pour nommer les ressources"
  default     = "cr460-demo"
}

variable "vm_size" {
  type        = string
  description = "Gabarit de la VM"
  default     = "Standard_D2als_v6"
}