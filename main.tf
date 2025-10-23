terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "terraform-assumido" # o el perfil local que uses
}

# --------------------------
# Repositorio ECR
# --------------------------
resource "aws_ecr_repository" "app_repo" {
  name = "proyectobase-runtime"
}

# --------------------------
# Instancia EC2
# --------------------------
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = "subnet-059b5e9a4cde735e4"      # subnet pública
  vpc_security_group_ids = ["sg-0e072a509dd0bbfe9"]        # grupo de seguridad existente
  associate_public_ip_address = true
  key_name               = "ec2-docker-key"
  iam_instance_profile   = "Rol-Instancia-Despliegue-EC2"

  user_data = <<-EOF
              #!/bin/bash
              echo "=== Inicializando instancia EC2 ===" > /var/log/userdata.log
              yum update -y
              amazon-linux-extras install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user
              docker run -d -p 80:80 842944705828.dkr.ecr.us-east-2.amazonaws.com/proyectobase-runtime:latest
              echo "=== EC2 lista con Docker ejecutando contenedor ===" >> /var/log/userdata.log
              EOF

  tags = {
    Name = "proyectobase-ec2"
  }
}

# --------------------------
# Elastic IP (creación y asociación automática)
# --------------------------
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  vpc      = true

  tags = {
    Name = "proyectobase-eip"
  }
}

# --------------------------
# Salidas
# --------------------------
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
