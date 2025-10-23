variable "region" {
  description = "Región donde se desplegarán los recursos"
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI Amazon Linux 2023 apta para free tier"
  default     = "ami-0341d95f75f311023"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  default     = "t3.micro"
}