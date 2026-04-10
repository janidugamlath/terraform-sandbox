output "generated_db_name" {
  value = random_pet.db_name.id
}

output "generated_password" {
  value     = random_password.password.result
  #sensitive = true
}


