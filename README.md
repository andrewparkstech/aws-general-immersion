# AWS General Immersion Day

Labs for AWS General Immersion Day, done in Terraform

Link: [AWS General Immersion Day](https://catalog.workshops.aws/general-immersionday/en-US)

### Intro
There are various labs over at AWS General Immersion Day. The one I completed was for EC2 Auto scaling. It walks you through setting it up using the console (GUI) but I decided to use Terraform because:
* I like a challenge
* It's fun

#### Files
`webhost.tf` within the ami folder was used to deploy the initial EC2 instance that I created a custom AMI from. Afterwards I destroyed that infrastructure.

### Authentication
Authentication to AWS for this lab is done via credentials supplied to the AWS command line (local credentials file). Best practice for production is to use AWS Identity Center.

### Tools
I used VS Code on a Windows machine and Windows Subsystem for Linux (WSL) for my terminal within VS Code, because I like Linux. AWS CLI and Terraform were then installed via the WSL command line. ChatGPT 4o and the Terraform documentation provided assitance for syntax and specific use cases, such as two security groups referencing themselves.

