output "elastic_ip" {
  description = "Dirección IP elástica asignada a la instancia"
  value       = aws_eip.app_eip.public_ip
}

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.app_server.id
}

output "app_url" {
  description = "URL para acceder a la app desplegada"
  value       = "http://${aws_eip.app_eip.public_ip}"
}
