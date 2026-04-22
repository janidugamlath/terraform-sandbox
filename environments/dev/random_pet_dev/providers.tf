terraform {
  cloud {

    organization = "codimite-janidu"

    workspaces {
      name = "dev-pet"
    }
  }
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
