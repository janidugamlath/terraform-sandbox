resource "random_pet" "server" {
  keepers = {
    ami_id = var.ami_id
  }
}