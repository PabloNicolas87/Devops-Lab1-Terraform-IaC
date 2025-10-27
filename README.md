# 🧱 DevOps-Lab1 – Infrastructure as Code (IaC) with Terraform

This repository contains the **Infrastructure as Code (IaC)** configuration used to deploy on AWS the base environment required for the **DevOps-Lab1** project.  
The infrastructure is fully managed with **Terraform**, allowing automated, repeatable, and secure provisioning and teardown of AWS resources.

---

## 🚀 Deployed Resources

This configuration creates the following core AWS components:

- **Amazon ECR (Elastic Container Registry):** Private Docker image repository.  
- **Amazon EC2 (Elastic Compute Cloud):** Virtual instance that runs the Docker container.  
- **Elastic IP:** Fixed public IP address associated with the EC2 instance.  
- **IAM Role & Instance Profile:** Grants permissions for EC2 to access ECR and use AWS Systems Manager (SSM).  
- **VPC (Virtual Private Cloud):** Isolated network that hosts the instance, including subnet, route table, and Internet Gateway.  

---

## 🗺️ Architecture Overview

```
                +--------------------------+
                |      AWS Account         |
                |                          |
                |   +------------------+   |
                |   |     ECR Repo     |   |
                |   +------------------+   |
                |            ↑             |
                |   (Pull image via IAM)   |
                |            |             |
                |   +------------------+   |
Internet ⇄ IGW ⇄ RT ⇄ Subnet ⇄ |  EC2 Instance  |
                |   | (Docker + App)   |   |
                |   +------------------+   |
                |            ↓             |
                |        Elastic IP        |
                +--------------------------+
```

---

## 📂 Project Structure

```
Devops-Terraform-IaC/
├── main.tf        # Main Terraform configuration (VPC, IAM, ECR, EC2, Elastic IP)
├── variables.tf   # Input variables (region, AMI, instance type)
├── outputs.tf     # Output values (ECR URL, EC2 ID, public IP)
├── .gitignore     # Ignored files and local state
└── README.md      # Project documentation
```

---

## ⚙️ Requirements

Before applying this configuration, make sure you have:

- **Terraform** installed → [Terraform installation guide](https://developer.hashicorp.com/terraform/downloads)  
- **AWS CLI** configured with a profile that assumes a Terraform role  
  Example: profile name `terraform-assumido` in `~/.aws/config`  
- An **AWS account** with permissions to create and delete:  
  - EC2 instances  
  - ECR repositories  
  - Elastic IPs  
  - IAM roles and VPC networking components  

---

## 🧭 Usage

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Preview the execution plan
```bash
terraform plan
```

### 3. Apply the configuration (create resources)
```bash
terraform apply
```
Confirm with `yes` when prompted.

After the deployment completes, Terraform will display:

- The ECR repository URL  
- The EC2 instance ID  
- The assigned public IP address  

### 4. Destroy all resources (to avoid extra costs)
```bash
terraform destroy
```
This command removes **every resource** created by this configuration.

---

## 🎯 Project Goal

This repository is part of my **Cloud Engineering learning path (Golden Path)**.  
Here I practice how to define and provision AWS infrastructure **declaratively** using Terraform — replicating the same setup I previously created manually.  

---

## 🧩 Technical Notes

- Default AMI: **Amazon Linux 2023** (`ami-0199d4b5b8b4fde0e`) in **us-east-2**.  
- Default instance type: **t3.micro** (Free Tier eligible).  
- Networking includes a single public subnet and Internet Gateway for outbound traffic.  
- EC2 User Data installs Docker, authenticates with ECR, pulls the latest image, and runs the container automatically.  
- Always run `terraform destroy` after finishing your tests to avoid incurring charges.  
