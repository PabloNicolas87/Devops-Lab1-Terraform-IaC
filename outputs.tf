output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 creada"
  value       = aws_instance.app_server.id
}

output "ec2_public_ip" {
  description = "Elastic IP pública asignada a la instancia EC2"
  value       = aws_eip.app_ip.public_ip
}
