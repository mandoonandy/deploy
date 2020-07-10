provider "aws" {
  profile = "default"
  region  = var.region
  version = "~> 2.27"
}

variable "region" {
  description = "AWS Region"
}
variable "ssh_key_name" {
  description = "Name of the AWS SSH Key to add to the VM instance"
}
variable "vpc_security_group_id" {
  description = "VPC security group ID"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "sf_single" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5d.metal"
  key_name      = var.ssh_key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 20
  }
  tags = {
    Name = "sf-single"
  }
    vpc_security_group_ids = [var.vpc_security_group_id]
}

output "sf_single_external" {
  value = aws_instance.sf_single.public_ip
}

output "sf_single_internal" {
  value = aws_instance.sf_single.private_ip
}
