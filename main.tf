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

variable "ami-id" {
  description = "ID for the AMI you want to use"
  default = "ami-09fe5b2a4a330c4e9" # custom AMI
}

# Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

# resource "aws_security_group" "web_server_sg" {
#   name        = "Immersion Day Web Server"
#   description = "Security group for web server allowing SSH and HTTP from anywhere"
#   vpc_id      = data.aws_vpc.default.id

#   ingress {
#     description = "Allow SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1" # Allows all outbound traffic
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Function = "AWS-ImmersionDay"
#   }
# }

# resource "aws_instance" "web_server" {
#   ami           = "ami-06c68f701d8090592" # Amazon Linux 2023 64-bit (x86)
#   instance_type = "t2.micro"
#   key_name = "AWS-ImmersionDay"
#   security_groups = [aws_security_group.web_server_sg.name]
#   user_data = file("${path.module}/userdata.sh")
#   iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  
#   tags = {
#     Function = "AWS-ImmersionDay"
#   }
# }

resource "aws_security_group" "Auto_Scaling_SG" {
  name        = "Auto Scaling SG"
  description = "Security group for ASG"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_security_group_rule" "asg_ingress_from_lb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.Auto_Scaling_SG.id
  source_security_group_id = aws_security_group.SG-Load-Balancer.id
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


#######################
# ASG and related items
#######################

resource "aws_launch_template" "asg_launch_template" {
  name = "asg_launch_template"
  image_id = var.ami-id
  instance_type = var.instance_type
  key_name = "AWS-ImmersionDay"
  monitoring {
    enabled = true
  }
  vpc_security_group_ids = [aws_security_group.Auto_Scaling_SG.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Function = "AWS-ImmersionDay"
    }
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "SG-Load-Balancer" {
  name        = "SG-Load-Balancer"
  description = "SG for the LB. Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ip_address]
  }

}

resource "aws_security_group_rule" "lb_egress_to_asg" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.SG-Load-Balancer.id
  source_security_group_id = aws_security_group.Auto_Scaling_SG.id
}

resource "aws_lb" "Application-Load-Balancer" {
  name               = "Application-Load-Balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG-Load-Balancer.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Function = "AWS-ImmersionDay"
  }
}

resource "aws_lb_target_group" "Target-Group" {
  name        = "Target-Group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Function = "AWS-ImmersionDay"
  }
}

resource "aws_lb_listener" "ALB-Listener" {
  load_balancer_arn = aws_lb.Application-Load-Balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Target-Group.arn
  }
}

resource "aws_autoscaling_group" "Webserver_ASG" {
  availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]
  desired_capacity   = 1
  min_size           = 1
  max_size           = 5
  target_group_arns = [aws_lb_target_group.Target-Group.arn]

  launch_template {
    id      = aws_launch_template.asg_launch_template.id
    version = "$Latest"
  }

  metrics_granularity = "1Minute"

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.Webserver_ASG.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 25.0
  }
}


# Outputs
output "ssm_instance_profile_arn" {
  value = aws_iam_instance_profile.ssm_instance_profile.arn
}
