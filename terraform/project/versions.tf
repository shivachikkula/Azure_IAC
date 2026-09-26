terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State lives in Azure Storage. The storage account comes from terraform/backend.hcl
  # (created by terraform/bootstrap/create-state-storage.sh); the state file key,
  # <project>/<environment>.tfstate, is passed at init time.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
