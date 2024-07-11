# AWS General Immersion Day

Labs for AWS General Immersion Day, done in Terraform

Link: [AWS General Immersion Day](https://catalog.workshops.aws/general-immersionday/en-US)

## Intro
There are various labs over at AWS General Immersion Day. It walks you through them using the console (GUI) but I decided to use Terraform because:
* I like a challenge
* It's fun

## Authentication
Authentication to AWS for this lab is done via credentials supplied to the AWS command line (local credentials file). Best practice for production is to use AWS Identity Center.

## Tools
I used VS Code on a Windows machine and Windows Subsystem for Linux (WSL) for my terminal within VS Code, because I like Linux. AWS CLI and Terraform were then installed via the WSL command line. ChatGPT 4o and the Terraform documentation provided assitance for syntax and specific use cases, such as two security groups referencing themselves.

## Modules

### EC2 Autoscaling

Auto Scaling automatically adjusts capacity and can be based on a number of different metrics. In this lab, we use CPU utilzation.

#### Files in `/ec2-autoscaling`

`webhost.tf` within the ami folder can be used to deploy an EC2 instance to create a custom AMI from.

`main.tf` The main terraform script uses the custom AMI in the launch template, which is then used in the autoscaling group.
