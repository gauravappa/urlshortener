terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    App = "gg"
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    App = "gg"
    Name = "main_igw"
  }
}

resource "aws_subnet" "main_public_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
    App = "gg"
    Name = "main_public_subnet"
  }
}

resource "aws_route_table" "main_public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = {
    App = "gg"
    Name = "main_public_rt"
  }
}

resource "aws_route_table_association" "main_public_rta" {
  route_table_id = aws_route_table.main_public_rt.id
  subnet_id = aws_subnet.main_public_subnet.id
}

resource "aws_security_group" "main_web_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    App = "gg"
    Name = "main_web_sg"
  }
}


# Generate a new SSH key pair in Terraform's memory
resource "tls_private_key" "internal_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload the public portion of that key to AWS
resource "aws_key_pair" "worker_key_pair" {
  key_name   = "jenkins_worker_key"
  public_key = tls_private_key.internal_ssh_key.public_key_openssh
}

resource "aws_instance" "jenkins_ec2" {
  ami = "ami-01a00762f46d584a1"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.main_public_subnet.id
  vpc_security_group_ids = [aws_security_group.main_web_sg.id]
  key_name = "jenkins_server_keypair"
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y

              # Install Java (required for Jenkins)
              sudo apt install fontconfig openjdk-21-jre -y

              # 1. Decode and save the private key to the ubuntu user's .ssh directory
              echo "${base64encode(tls_private_key.internal_ssh_key.private_key_pem)}" | base64 -d > /home/ubuntu/.ssh/id_rsa

              # 2. Set the strict permissions required by SSH
              chmod 400 /home/ubuntu/.ssh/id_rsa
              chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

              # Add Jenkins GPG key and Debian repository
              sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
              https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

              echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
              https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
              /etc/apt/sources.list.d/jenkins.list > /dev/null

              # Install Jenkins
              sudo apt-get update -y
              sudo apt-get install jenkins -y

              # Start and enable Jenkins
              sudo systemctl enable jenkins
              sudo systemctl start jenkins
              EOF

  tags = {
    Name = "jenkins_server"
  }
}

resource "aws_instance" "jenkins_agent_ec2" {
  ami = "ami-01a00762f46d584a1"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.main_public_subnet.id
  vpc_security_group_ids = [aws_security_group.main_web_sg.id]
  key_name = aws_key_pair.worker_key_pair.key_name
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y

              # Install Java (required for Jenkins)
              sudo apt install fontconfig openjdk-21-jre -y

              EOF

  tags = {
    Name = "jenkins_agent_server"
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins_ec2.public_ip}:8080"
}

# Output the private IP so you know where Jenkins needs to connect
output "worker_node_private_ip" {
  value = aws_instance.jenkins_agent_ec2.public_ip
}