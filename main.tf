terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

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

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Declaration du groupe de ressources principal
resource "azurerm_resource_group" "myResourceGroup" {
  name     = "DEMO-PPL-10-demo-az-vcs"
  location = "eastus"
}