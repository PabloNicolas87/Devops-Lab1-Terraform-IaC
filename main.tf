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
  profile = "terraform-assumido" # o el perfil que uses localmente
}

# --------------------------
# Repositorio ECR
# --------------------------
resource "aws_ecr_repository" "app_repo" {
  name         = "proyectobase-runtime"
  force_delete = true
}

# --------------------------
# Instancia EC2
# --------------------------
resource "aws_instance" "app_server" {
  ami                         = var.ami_id
  instance_type                = var.instance_type
  subnet_id                    = "subnet-059b5e9a4cde735e4"   # subnet pública
  vpc_security_group_ids       = ["sg-0e072a509dd0bbfe9"]     # grupo de seguridad existente
  associate_public_ip_address  = true
  key_name                     = "ec2-docker-key"
  iam_instance_profile         = "Rol-Instancia-Despliegue-EC2"

  user_data = <<-EOF
              #!/bin/bash
              echo "=== Inicializando instancia EC2 ===" > /var/log/userdata.log

              # Actualizar e instalar Docker en Amazon Linux 2023
              sudo dnf update -y
              sudo dnf install docker -y
              sudo systemctl enable docker
              sudo systemctl start docker
              sudo usermod -aG docker ec2-user

              # Instalar y habilitar SSM Agent
              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable amazon-ssm-agent
              sudo systemctl start amazon-ssm-agent

              # Login en ECR y ejecutar contenedor
              REGION="us-east-2"
              ACCOUNT_ID="842944705828"
              REPO_NAME="proyectobase-runtime"
              IMAGE_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"

              sudo aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
              sudo docker pull $IMAGE_URL
              sudo docker run -d -p 80:80 $IMAGE_URL

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
  domain = "vpc"
  tags = {
    Name = "proyectobase-eip"
  }
}

resource "aws_eip_association" "app_eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_eip.id
}
