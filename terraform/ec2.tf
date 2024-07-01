# Variables
variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
}

# Check if the security group exists
data "aws_security_group" "existing_strapi_sg" {
  name = "ashwani-security-group"
}

# If the security group exists, use its ID; otherwise, create a new one
resource "aws_security_group" "strapi_sg" {
  count       = length(data.aws_security_group.existing_strapi_sg.ids) > 0 ? 0 : 1
  name        = "ashwani-security-group"
  description = "Security group for Strapi EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
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

# AMI Data Source
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Canonical's AWS account ID
}

# EC2 Instance
resource "aws_instance" "strapi" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.strapi_sg.id]

  tags = {
    Name = "AshwaniStrapiServer"
  }

  provisioner "remote-exec" {
  inline = [
    "sudo apt update -y",
    "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -",
    "sudo apt-get install -y nodejs",
    "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash",
    "export NVM_DIR=\"$HOME/.nvm\"",
    "[ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\"",
    "[ -s \"$NVM_DIR/bash_completion\" ] && . \"$NVM_DIR/bash_completion\"",
    "source ~/.bashrc",
    "mkdir -p /home/ubuntu/.npm && sudo chown -R ubuntu:ubuntu /home/ubuntu/.npm",
    "nvm install 18",
    "sudo npm install -g pm2",
    "git clone https://github.com/veera1016/strapi.git"
  ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }
}

# Output
output "instance_ip" {
  value = aws_instance.strapi.public_ip
}
