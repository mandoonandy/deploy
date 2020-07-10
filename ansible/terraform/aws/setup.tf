provider "aws" {
  profile = "default"
  region  = var.region
  version = "~> 2.27"
}

#
# Input variables
#
variable "region" {
  description = "AWS Region"
}
variable "ssh_key_name" {
  description = "Name of the AWS SSH Key to add to the VM instance"
}
variable "uniqifier" {
  description = "Unique instance name prefix to identify the cluster"
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

#
# Resource configuration
#
resource "aws_instance" "sf_1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5d.metal"
  key_name      = var.ssh_key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 20
  }
  tags = {
    Name = "${var.uniqifier}sf-1"
  }
  vpc_security_group_ids = [var.vpc_security_group_id]
}

resource "aws_instance" "sf_2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5d.metal"
  key_name      = var.ssh_key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 20
  }
  tags = {
    Name = "${var.uniqifier}sf-2"
  }
  vpc_security_group_ids = [var.vpc_security_group_id]
}

resource "aws_instance" "sf_3" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5d.metal"
  key_name      = var.ssh_key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 20
  }
  tags = {
    Name = "${var.uniqifier}sf-3"
  }
  vpc_security_group_ids = [var.vpc_security_group_id]
}

#
# Outputs
#
output "sf_1_external" {
  value = aws_instance.sf_1.public_ip
}

output "sf_2_external" {
  value = aws_instance.sf_2.public_ip
}

output "sf_3_external" {
  value = aws_instance.sf_3.public_ip
}

output "sf_1_internal" {
  value = aws_instance.sf_1.private_ip
}

output "sf_2_internal" {
  value = aws_instance.sf_2.private_ip
}

output "sf_3_internal" {
  value = aws_instance.sf_3.private_ip
}
