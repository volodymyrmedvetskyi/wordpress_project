provider "aws" {
  region = var.region
}

# Створюємо VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

# Створюємо публічну підмережу та дозволяємо присвоєння публічного IP
resource "aws_subnet" "my_vpc_public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "my-vpc-public-subnet"
  }
}

# Створюємо 2 приватні підмережі у різних availability zones
resource "aws_subnet" "my_vpc_private_subnet" {
  for_each          = { for i, block in var.private_subnets_cidr_blocks : i + 1 => block }
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key - 1]

  tags = {
    Name = "my-vpc-private-subnet-${each.key}"
  }
}

# Створюємо internet gateway для VPC
resource "aws_internet_gateway" "my_vpc_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-vpc-internet-gateway"
  }
}

# Створюємо elastic IP
resource "aws_eip" "my_vpc_eip" {
}

# Створюємо nat gateway для можливості виходу в інтернет приватних підмереж
resource "aws_nat_gateway" "my_vpc_nat_gateway" {
  subnet_id     = aws_subnet.my_vpc_public_subnet.id
  allocation_id = aws_eip.my_vpc_eip.id

  tags = {
    Name = "my-vpc-nat-gateway"
  }
}

# Створюємо route table для публічної мережі
resource "aws_route_table" "my_vpc_public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_internet_gateway.id
  }

  tags = {
    Name = "my-vpc-public-route-table"
  }
}

# Створюємо асоціацію route table для публічної мережі з публічною підмережею
resource "aws_route_table_association" "my_vpc_public_route_table_association" {
  route_table_id = aws_route_table.my_vpc_public_route_table.id
  subnet_id      = aws_subnet.my_vpc_public_subnet.id
}

# Створюємо route table для приватних підмереж
resource "aws_route_table" "my_vpc_private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_vpc_nat_gateway.id
  }

  tags = {
    Name = "my-vpc-private-route-table"
  }
}

# Створюємо асоціацію route table для приватних мереж з кожною приватною підмережею
resource "aws_route_table_association" "my_vpc_private_route_table_association" {
  for_each       = aws_subnet.my_vpc_private_subnet
  route_table_id = aws_route_table.my_vpc_private_route_table.id
  subnet_id      = each.value.id
}

# Створюємо окрему security групу для EC2 інстанса
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2-security-group"
  description = "Inbound and outbound rules for EC2 Instance"
  vpc_id      = aws_vpc.my_vpc.id

  dynamic "ingress" {
    for_each = var.ec2_ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Створюємо окремо security групу для MySQL RDS
resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Inbound and outbound rules for MySQL RDS Instance"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Створюємо окремо security групу для ElastiCache Redis
resource "aws_security_group" "elasticache_security_group" {
  name        = "elasticache-security-group"
  description = "Inbound and outbound rules for ElastiCache Redis Instance"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Створюємо пару ключів для можливості SSH до EC2 інстансу
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "ec2-key-pair"
  public_key = file(var.public_key_path)
}

# Створюємо EC2 інстанс у публічній підмережі
resource "aws_instance" "ec2_instance" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  key_name        = "ec2-key-pair"
  subnet_id       = aws_subnet.my_vpc_public_subnet.id
  security_groups = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = "ec2-instance"
  }
}

# Створюємо групу підмереж для RDS інстансу у приватних підмережах
resource "aws_db_subnet_group" "mysql_rds_subnet_group" {
  name        = "mysql-rds-subnet-group"
  description = "Subnet group for MySQL RDS Instance"
  subnet_ids  = values(aws_subnet.my_vpc_private_subnet)[*].id
}

# Створюємо MySQL RDS інстанс з базою даних, користувачем і паролем у приватній підмережі
resource "aws_db_instance" "mysql_rds_instance" {
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  identifier             = "mysql-rds-instance"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.mysql_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# Створюємо групу підмереж для ElastiCache Redis у приватних підмережах
resource "aws_elasticache_subnet_group" "elasticache_redis_subnet_group" {
  name        = "elasticache-redis-subnet-group"
  description = "Subnet group for ElastiCache Redis"
  subnet_ids  = values(aws_subnet.my_vpc_private_subnet)[*].id
}

# Створюємо ElastiCache Redis cluster з однією нодою для кешування у приватній підмережі
resource "aws_elasticache_cluster" "elasticache_redis" {
  cluster_id         = "elasticache-redis"
  engine             = "redis"
  node_type          = "cache.t4g.micro"
  num_cache_nodes    = 1
  port               = var.redis_port
  subnet_group_name  = aws_elasticache_subnet_group.elasticache_redis_subnet_group.name
  security_group_ids = [aws_security_group.elasticache_security_group.id]
}