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
  profile = "terraform-assumido"
}

# --------------------------
# 1. IAM ROLE PARA EC2
# --------------------------
resource "aws_iam_role" "ec2_role" {
  name = "Rol-Instancia-Despliegue-EC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# Políticas necesarias (ECR + CloudWatch + SSM)
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "Rol-Instancia-Despliegue-EC2"
  role = aws_iam_role.ec2_role.name
}

# --------------------------
# 2. NETWORKING (VPC)
# --------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vpc-laboratorio-fargate" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = { Name = "igw-laboratorio-fargate" }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-publica-a" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "rtb-laboratorio-fargate" }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# --------------------------
# 3. SECURITY GROUP
# --------------------------
resource "aws_security_group" "web_sg" {
  name        = "fargate-web-access-final"
  description = "Permitir HTTP y SSH"
  vpc_id      = aws_vpc.main_vpc.id

  ingress = [
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = { Name = "fargate-web-access-final" }
}

# --------------------------
# 4. PAR DE CLAVES SSH
# --------------------------
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_keypair" {
  key_name   = "ec2-docker-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Guardar el .pem localmente
resource "local_file" "private_key_pem" {
  filename = "${path.module}/ec2-docker-key.pem"
  content  = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400"
}

# --------------------------
# 5. REPOSITORIO ECR
# --------------------------
resource "aws_ecr_repository" "app_repo" {
  name         = "proyectobase-runtime"
  force_delete = true
}

# --------------------------
# 6. INSTANCIA EC2
# --------------------------
resource "aws_instance" "app_server" {
  ami                         = var.ami_id
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.public_subnet_a.id
  vpc_security_group_ids       = [aws_security_group.web_sg.id]
  associate_public_ip_address  = true
  key_name                     = aws_key_pair.ec2_keypair.key_name
  iam_instance_profile         = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "=== Inicializando instancia EC2 ===" > /var/log/userdata.log

              sudo dnf update -y
              sudo dnf install docker -y
              sudo systemctl enable docker
              sudo systemctl start docker
              sudo usermod -aG docker ec2-user

              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable amazon-ssm-agent
              sudo systemctl start amazon-ssm-agent

              REGION="${var.region}"
              ACCOUNT_ID="842944705828"
              REPO_NAME="proyectobase-runtime"
              IMAGE_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"

              sudo aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
              sudo docker pull $IMAGE_URL
              sudo docker run -d -p 80:80 $IMAGE_URL

              echo "=== EC2 lista con Docker ejecutando contenedor ===" >> /var/log/userdata.log
              EOF

  tags = { Name = "proyectobase-ec2" }
}

# --------------------------
# 7. ELASTIC IP + ASOCIACIÓN
# --------------------------
resource "aws_eip" "app_eip" {
  domain = "vpc"
  tags   = { Name = "proyectobase-eip" }
}

resource "aws_eip_association" "app_eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_eip.id
}