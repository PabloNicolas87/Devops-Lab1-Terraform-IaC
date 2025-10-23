# IaC – React Docker en AWS con Terraform

Este proyecto contiene la **infraestructura como código (IaC)** para desplegar en AWS los recursos necesarios para ejecutar un pipeline CI/CD de una aplicación React containerizada.  
La infraestructura se gestiona con **Terraform**, lo que permite crear y destruir recursos de forma automática, reproducible y segura.

---

## 🚀 Recursos desplegados
Con esta configuración se crean los siguientes servicios en AWS:

- **Amazon ECR (Elastic Container Registry):** repositorio privado de imágenes Docker.  
- **Amazon EC2 (Elastic Compute Cloud):** instancia virtual para ejecutar el contenedor.  
- **Elastic IP:** dirección IP pública fija asociada a la instancia EC2.  

---

## 📂 Estructura del proyecto
```
iac-react-docker-ec2/
├── main.tf        # Recursos principales (ECR, EC2, Elastic IP)
├── variables.tf   # Variables configurables (región, tipo de instancia, AMI)
├── outputs.tf     # Valores de salida (ECR URL, ID EC2, IP pública)
├── .gitignore     # Archivos que no deben subirse a git
└── README.md      # Documentación del proyecto
```

---

## ⚙️ Requisitos previos
1. **Terraform** instalado en tu máquina ([guía oficial](https://developer.hashicorp.com/terraform/downloads)).  
2. **AWS CLI** configurado con un perfil que asuma el rol `TerraformRole`.  
   - Ejemplo: `terraform-assumido` en `~/.aws/config`.  
3. Una cuenta de AWS con permisos para crear/borrar recursos EC2, ECR y Elastic IP.

---

## 📝 Uso

### 1. Inicializar Terraform
```bash
terraform init
```

### 2. Ver plan de ejecución
```bash
terraform plan
```

### 3. Aplicar cambios (crear recursos)
```bash
terraform apply
```
Confirma con `yes` cuando Terraform lo pida.

Al finalizar, Terraform mostrará:
- URL del repositorio ECR  
- ID de la instancia EC2  
- IP pública asignada

### 4. Destruir infraestructura (evitar costos)
```bash
terraform destroy
```

Esto elimina todos los recursos creados.

---

## 🎯 Objetivo del proyecto
Este repositorio es el segundo módulo de mi **Golden Path de Cloud Engineering**.  
Aquí aprendo a manejar **infraestructura como código** para levantar de forma declarativa los mismos recursos que antes creaba manualmente.  
El próximo paso será integrar servicios serverless (Lambda, S3, API Gateway).

---

## 📌 Notas
- La configuración usa una AMI de **Amazon Linux 2023** (`ami-0341d95f75f311023`) en `us-east-1`.  
- El tipo de instancia por defecto es `t3.micro` (incluida en el Free Tier).  
- Recordar ejecutar `terraform destroy` después de cada práctica.  

