variable "ami_id" {
  type        = string
  default     = "test-id6"
  description = "The ID used to trigger a name change"
}
resource "random_pet" "server" {
  keepers = {
    ami_id = var.ami_id
  }
}
