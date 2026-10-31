terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# 1. Groupe de ressources (parametrage region + nom)
resource "azurerm_resource_group" "myResourceGroup" {
  name     = "${var.resource_prefix}-rg"
  location = var.azure_region
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

# 6. Machine virtuelle Linux Ubuntu (parametrage taille VM)
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "${var.resource_prefix}-vm"
  resource_group_name             = azurerm_resource_group.myResourceGroup.name
  location                        = azurerm_resource_group.myResourceGroup.location
  size                            = var.vm_size
  admin_username                  = "azureuser"
  admin_password                  = "AdminLab2026!#"
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
}

# 7. Conteneur ACI
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
}