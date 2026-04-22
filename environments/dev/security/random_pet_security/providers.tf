terraform {
  cloud {

    organization = "codimite-janidu"

    workspaces {
      name = "security-password"
    }
  }
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}


