terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # AJOUT Q12 : pour générer le mot de passe et le nom unique
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    # AJOUT Q12 : gestion du cycle de vie du Key Vault
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Récupère l'identité du Service Principal pour lui donner les droits sur le coffre
data "azurerm_client_config" "current" {}

# AJOUT Q12 : suffixe aléatoire car le nom d'un Key Vault est mondialement unique
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Groupe de ressources (parametrage region + nom)
resource "azurerm_resource_group" "myResourceGroup" {
  name     = "${var.resource_prefix}-rg"
  location = var.azure_region
  tags     = var.common_tags
}

# 2. Reseau virtuel (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myResourceGroup.location
  resource_group_name = azurerm_resource_group.myResourceGroup.name
}

# 3. Sous-reseau (Subnet)
resource "azurerm_subnet" "subnet" {
  name                 = "${var.resource_prefix}-snet"
  resource_group_name  = azurerm_resource_group.myResourceGroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Adresse IP Publique
resource "azurerm_public_ip" "pip" {
  name                = "${var.resource_prefix}-pip"
  location            = azurerm_resource_group.myResourceGroup.location
  resource_group_name = azurerm_resource_group.myResourceGroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Interface reseau (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "${var.resource_prefix}-nic"
  location            = azurerm_resource_group.myResourceGroup.location
  resource_group_name = azurerm_resource_group.myResourceGroup.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 1. Génération automatique du mot de passe fort
resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Création du coffre Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.resource_prefix}-${random_string.suffix.result}"
  location                    = azurerm_resource_group.myResourceGroup.location
  resource_group_name         = azurerm_resource_group.myResourceGroup.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
  tags = var.common_tags
}

# 3. Enregistrement du secret dans le coffre
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.kv.id
}

# Machine virtuelle Linux Ubuntu (parametrage taille VM)
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "${var.resource_prefix}-vm"
  resource_group_name             = azurerm_resource_group.myResourceGroup.name
  location                        = azurerm_resource_group.myResourceGroup.location
  size                            = var.vm_size
  admin_username                  = "azureuser"
  admin_password                  = azurerm_key_vault_secret.vm_admin_password.value
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  tags = var.common_tags
}

# Conteneur ACI
resource "azurerm_container_group" "aci" {
  name                = "${var.resource_prefix}-aci"
  location            = azurerm_resource_group.myResourceGroup.location
  resource_group_name = azurerm_resource_group.myResourceGroup.name
  ip_address_type     = "Public"
  dns_name_label      = "${var.resource_prefix}-aci-simo"
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    cpu    = "1.0"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
  tags = var.common_tags
}