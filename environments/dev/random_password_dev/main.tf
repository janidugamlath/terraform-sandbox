resource "random_pet" "db_name" {
  prefix = var.pet_prefix
  length = 3
}

resource "random_pet" "db_name1" {
  prefix = var.pet_prefix
  length = 3
}

resource "random_password" "password" {
  length           = var.password_length
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}



