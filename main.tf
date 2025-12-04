terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.location
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc-${terraform.workspace}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw-${terraform.workspace}"
  }
}

# Create Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.az

  tags = {
    Name = "public-subnet-${terraform.workspace}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.az

  tags = {
    Name = "private-subnet-${terraform.workspace}"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip-${terraform.workspace}"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat-gw-${terraform.workspace}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Create Route Tables
# Public RT → IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Private RT → NAT
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Create Security Groups
resource "aws_security_group" "public_sg" {
  name        = "public-sg-${terraform.workspace}"
  description = "Allow SSH from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg-${terraform.workspace}"
  description = "Allow SSH only from public EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "latest-amazon-ubuntu-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location) # Path to your public key file
}

# Create the EC2 Public Instance
resource "aws_eip" "public_ec2_eip" {
  instance = aws_instance.public_ec2.id

  tags = {
    Name = "public-ec2-eip-${terraform.workspace}"
  }
}

resource "aws_instance" "public_ec2" {
  ami           = data.aws_ami.latest-amazon-ubuntu-image.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.ssh-key.key_name
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  availability_zone = var.az
  associate_public_ip_address = true

  tags = {
    Name = "public-ec2-${terraform.workspace}"
  }
}

# Create the EC2 Private Instance
resource "aws_instance" "private_ec2" {
  ami           = data.aws_ami.latest-amazon-ubuntu-image.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_subnet.id
  key_name      = aws_key_pair.ssh-key.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  availability_zone = var.az

  tags = {
    Name = "private-ec2-${terraform.workspace}"
  }
}
