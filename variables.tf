# Перелік всіх змінних, для кожної змінної вказано дефолтне значення, змінити значення
# можна у файлі terraform.tfvars

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ec2_ingress_ports" {
  description = "Inbound ports for EC2 Instance"
  type        = list(number)
  default     = [22, 80]
}

variable "public_key_path" {
  description = "The path to SSH Public Key"
  type        = string
  default     = "ec2-key-pair.pub"
}

variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password for the master DB user"
  type        = string
  default     = "passw0rd_123"
}

variable "redis_port" {
  description = "The open port for ElastiCache Redis"
  type        = number
  default     = 6379
}