resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "example" {
  instance_class    = "db.t3.micro"
  allocated_storage = var.storage_size
  engine            = "mysql"
  username          = var.db_username
  password          = random_password.password.result
  
  # Note: Since you have no infra, a 'terraform plan' will work,
  # but 'apply' will fail unless you have AWS credentials set up.
  skip_final_snapshot = true 
}output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.example.address
}

output "db_password" {
  description = "The generated password (marked sensitive)"
  value       = random_password.password.result
  sensitive   = true
}