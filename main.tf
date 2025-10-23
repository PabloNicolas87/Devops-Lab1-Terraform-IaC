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
  profile = "terraform-assumido" # usamos el perfil que asume el rol
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
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "proyectobase-ec2"
  }
}

# --------------------------
# Elastic IP
# --------------------------
resource "aws_eip" "app_ip" {
  instance = aws_instance.app_server.id
  vpc      = true
}
