terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    #  version = "5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
}

/*
output "ami_latest" {
  value = data.aws_ami.latest_amazon_linux.id
  description = "This is the latest AMI ID"
}
*/

# Security Group for SSH Access
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Allow SSH access for EC2 Instance Connect"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to all (restrict for security)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for EC2 Instance Connect
resource "aws_iam_role" "ec2_instance_connect" {
  name = "EC2InstanceConnectRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach EC2 Instance Connect IAM Policy
resource "aws_iam_policy_attachment" "ec2_connect_attach" {
  name       = "ec2-connect-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  roles      = [aws_iam_role.ec2_instance_connect.name]
}

# Create IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_instance_connect.name
}

# Create EC2 Instance
resource "aws_instance" "myecs2" {
  ami           = "ami-08b5b3a93ed654d19"  # Amazon Linux 2023 AMI
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_ssh.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  user_data = <<EOF
    #!/bin/bash
    # Use this for your user data (script from top to bottom)
    # install httpd (Linux 2 version)
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Linux-Instance-1"
  }
}
