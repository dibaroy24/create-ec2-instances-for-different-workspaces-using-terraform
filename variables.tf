variable location {
    description = "The location where resources are created"
    default     = "us-east-1"
}

variable "az" {
  default = "us-east-1a"
}

variable vpc_cidr_block {
    description = "The CIDR block reserved for the VPC"
    default     = "10.0.0.0/16"
}

variable public_subnet_cidr_block {
    description = "The CIDR block reserved for the public subnet-1"
    default     = "10.0.1.0/24"
}

variable private_subnet_cidr_block {
    description = "The CIDR block reserved for the public subnet-2"
    default     = "10.0.2.0/24"
}

variable public_key_location {
    description = "Path to the public key file for the EC2 key pair"
    type        = string
    default     = "~/.ssh/my_tfkey.pub" # Example default path
}

variable instance_type {
    description = "The size of the instance"
    default = "t2.micro"
}
