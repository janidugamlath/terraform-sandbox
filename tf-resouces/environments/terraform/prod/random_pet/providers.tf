terraform {
  cloud {

    organization = "codimite-janidu"

    workspaces {
      name = "prod-pet"
    }
  }
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}