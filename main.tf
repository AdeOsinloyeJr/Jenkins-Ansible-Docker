# Get your current public IP (only used if var.ssh_cidr is null)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  ssh_cidr_effective = var.ssh_cidr != null ? var.ssh_cidr : "${chomp(data.http.my_ip.response_body)}/32"
}

# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the latest Ubuntu 22.04 LTS (Jammy) AMI for x86_64
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ssh_only" {
  name        = "demo-ssh-only"
  description = "Allow SSH from my IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.ssh_cidr_effective]
  }

  ingress {
    description = "Jenkins HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.ssh_cidr_effective]
  }

   # NEW: allow 8080 from within the VPC (agents -> controller)
  ingress {
    description = "Jenkins HTTP from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }


  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-ssh-only"
  }
}

resource "aws_key_pair" "laptop" {
  key_name   = "LaptopKey"
  public_key = file("/mnt/c/Users/adedi/Downloads/LaptopKey.pub")
}

locals {
  instance_configs = {
    controller = {
      name      = "jenkins-controller"
      user_data = file("controller-user-data.sh")
    }
    agent1 = {
      name      = "jenkins-agent-1"
      user_data = file("agent-user-data.sh")
    }
    agent2 = {
      name      = "jenkins-agent-2"
      user_data = file("agent-user-data.sh")
    }
  }
}

resource "aws_instance" "demo" {
  for_each               = local.instance_configs
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  key_name               = aws_key_pair.laptop.key_name
  user_data              = each.value.user_data

  tags = {
    Name = each.value.name
  }
}
