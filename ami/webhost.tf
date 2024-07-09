# AWS General Immersion Day - EC2 Auto Scaling
# This terraform file deploys a single EC2 instance as a web server, to create an AMI from
# It uses a security group that allows ingress ports 80 and 22 from anywhere and all egress traffic
# You can customize some of the values, such as IP address to allow for ingress traffic, by specifying terraform varables in one of the supported ways
# https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files


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

variable "ami_id" {
  description = "The AMI ID"
  default     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

variable "instance_type" {
  description = "Web Host EC2 instance type"
  default     = "t2.micro"
}

variable "ip_address" {
  description = "Your local IP address followed by a /32 to restrict HTTP(80) access"
  default = "0.0.0.0/0"
}

variable "aws_region" {
  description = "AWS Region"
  default = "us-east-1"
}

variable "key_name" {
  description = "The key pair name to use for the EC2 instance"
  default = "AWS-ImmersionDay"
}

data "aws_ssm_parameter" "ami_id" {
  name = var.ami_id
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

data "aws_subnet" "default" {
  id = data.aws_subnets.default.ids[0]
}

# Mapping equivalent for EC2 image URLs
locals {
  vpc_id = data.aws_vpc.default.id
  subnet_id = data.aws_subnet.default.id
  ec2_image_map = {
    "us-west-1"      = "https://ws-assets-prod-iad-r-sfo-f61fc67057535f1b.s3.us-west-1.amazonaws.com/f3a3e2bd-e1d5-49de-b8e6-dac361842e76/ec2-web-host.tar"
    "us-west-2"      = "https://ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0.s3.us-west-2.amazonaws.com/f3a3e2bd-e1d5-49de-b8e6-dac361842e76/ec2-web-host.tar"
    "us-east-1"      = "https://ws-assets-prod-iad-r-iad-ed304a55c2ca1aee.s3.us-east-1.amazonaws.com/f3a3e2bd-e1d5-49de-b8e6-dac361842e76/ec2-web-host.tar"
    "us-east-2"      = "https://ws-assets-prod-iad-r-cmh-8d6e9c21a4dec77d.s3.us-east-2.amazonaws.com/f3a3e2bd-e1d5-49de-b8e6-dac361842e76/ec2-web-host.tar"
    "ap-southeast-1" = "https://ws-assets-prod-iad-r-sin-694a125e41645312.s3.ap-southeast-1.amazonaws.com/f3a3e2bd-e1d5-49de-b8e6-dac361842e76/ec2-web-host.tar"
  }
  ec2_image = local.ec2_image_map[var.aws_region]
}

resource "aws_security_group" "webhost_security_group" {
  vpc_id      = local.vpc_id
  name        = "webhost-security-group"
  description = "Allow access to the Webhost on Port 80"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ip_address]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webhost-security-group"
    Function = "AWS_Immersion"
  }
}

resource "aws_instance" "web_server_instance" {
  ami           = data.aws_ssm_parameter.ami_id.value
  instance_type = var.instance_type
  subnet_id     = local.subnet_id
  security_groups = [aws_security_group.webhost_security_group.id]
  associate_public_ip_address = true
  key_name = var.key_name

  user_data = <<-EOF
              #!/bin/bash -xe
              yum -y update
              yum -y install httpd
              amazon-linux-extras install php7.2
              yum -y install php-mbstring
              yum -y install telnet
              case $(ps -p 1 -o comm | tail -1) in
              systemd) systemctl enable --now httpd ;;
              init) chkconfig httpd on; service httpd start ;;
              *) echo "Error starting httpd (OS not using init or systemd)." 2>&1
              esac
              cd /var/www/html
              wget ${local.ec2_image}
              tar xvf ec2-web-host.tar
              EOF

  tags = {
    Name = "Web Server"
    Function = "AWS_Immersion"
  }
}

output "public_ip" {
  value       = aws_instance.web_server_instance.public_ip
  description = "Newly created webhost Public IP"
}

output "public_dns" {
  value       = aws_instance.web_server_instance.public_dns
  description = "Newly created webhost Public DNS URL"
}
