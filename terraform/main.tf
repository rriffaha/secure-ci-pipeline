data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_security_group" "secure_ci_sg" {
  name        = "secure-ci-sg"
  description = "Allow SSH and app access"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App Port"
    from_port   = 8080
    to_port     = 8080
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

resource "aws_instance" "secure_ci_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.secure_ci_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user
              docker pull rriffaha/demo:16
              docker run -d -p 8080:8080 --name secure-ci-app rriffaha/demo:16 || true
              EOF

  tags = {
    Name = "secure-ci-ec2"
  }
}