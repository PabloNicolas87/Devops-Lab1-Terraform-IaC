##############################################
# 0. CONFIGURACIÓN BASE
##############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Proveedor AWS ---
provider "aws" {
  region  = var.region
  profile = "terraform-assumido"

  # Etiquetas automáticas para todos los recursos
  default_tags {
    tags = {
      Project = "proyectobase"
      Env     = "lab"
      Owner   = "Pablo"
    }
  }
}

# --- Datos dinámicos útiles ---
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  repo_name  = "proyectobase-runtime"
  image_tag  = "latest"
}

##############################################
# 1. IAM ROLE Y PERFIL PARA EC2
##############################################

# Rol para que EC2 pueda acceder a ECR y SSM
resource "aws_iam_role" "ec2_role" {
  name = "Rol-Instancia-Despliegue-EC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Permiso de solo lectura a ECR
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Permiso para acceder por Session Manager (SSM)
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Perfil de instancia que vincula el rol a la EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "Rol-Instancia-Despliegue-EC2"
  role = aws_iam_role.ec2_role.name
  depends_on = [aws_iam_role.ec2_role]
}

##############################################
# 2. NETWORKING
##############################################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "proyectobase-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "proyectobase-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "proyectobase-subnet-public-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "proyectobase-rt-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

##############################################
# 3. SECURITY GROUP
##############################################

resource "aws_security_group" "web_sg" {
  name        = "proyectobase-sg"
  description = "Permitir trafico HTTP publico"
  vpc_id      = aws_vpc.main.id

  ingress = [
    {
      description      = "HTTP publico"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "Salida libre"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = { Name = "proyectobase-sg" }
}

##############################################
# 4. REPOSITORIO ECR
##############################################

resource "aws_ecr_repository" "app_repo" {
  name         = local.repo_name
  force_delete = true
  tags         = { Name = "proyectobase-ecr" }
}

##############################################
# 5. INSTANCIA EC2
##############################################

resource "aws_instance" "app_server" {
  ami                        = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    REGION="${var.region}"
    ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
    REPO_NAME="${local.repo_name}"
    IMAGE_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:${local.image_tag}"

    echo "=== Instalando Docker ==="
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user

    echo "=== Login en ECR ==="
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

    echo "=== Ejecutando contenedor ==="
    docker pull "$IMAGE_URL"
    docker run -d --restart always -p 80:80 "$IMAGE_URL"

    echo "=== Setup completado ==="
  EOF

  tags = { Name = "proyectobase-ec2" }
}

##############################################
# 6. ELASTIC IP
##############################################

resource "aws_eip" "app_eip" {
  domain = "vpc"
  tags   = { Name = "proyectobase-eip" }
}

resource "aws_eip_association" "app_eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_eip.id
}
