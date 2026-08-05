terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  # Features left default.
  # Note: to authenticate using GitHub Actions OIDC (workload identity federation),
  # set the environment variable `ARM_USE_OIDC=true` in the process running Terraform
  # (the GitHub Actions workflow already exports this). The AzureRM provider will
  # pick up OIDC-based credentials when available.
  features {}
}
