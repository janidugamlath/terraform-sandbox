terraform {
  cloud {

    organization = "codimite-janidu"

    workspaces {
      name = "codimite"
    }
  }


  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
