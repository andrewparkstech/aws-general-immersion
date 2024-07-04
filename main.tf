terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web_server_sg" {
  name        = "Immersion Day Web Server"
  description = "Security group for web server allowing SSH and HTTP from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Function = "AWS-ImmersionDay"
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-06c68f701d8090592" # Amazon Linux 2023 64-bit (x86)
  instance_type = "t2.micro"
  key_name = "AWS-ImmersionDay"
  security_groups = [aws_security_group.web_server_sg.name]
  user_data = file("${path.module}/userdata.sh")
  
  tags = {
    Function = "AWS-Immersion"
  }
}
