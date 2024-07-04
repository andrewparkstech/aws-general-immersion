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
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  
  tags = {
    Function = "AWS-Immersion"
  }
}

resource "aws_iam_role" "ssm_instance_role" {
  name = "SSMInstanceProfile"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_instance_role.name
}

output "ssm_instance_profile_arn" {
  value = aws_iam_instance_profile.ssm_instance_profile.arn
}
