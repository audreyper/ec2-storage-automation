terraform {
  
      required_version = "~>1.7.2"
      required_providers {
        jinja = {
           source = "NikolaLohinski/jinja"
           version = ">=2.0.1"
             }
           }
 }

# Create a security group for instances 
resource "aws_security_group" "ssh_group" {
  name        = "ssh_group"
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from any IP address
  }
}

# Prepare jinja templates
locals {
  yaml_file = yamldecode(file("${path.module}/data.yml"))
}

# Prepare jinja template for instance creation block
data "jinja_template" "instance_creation" {
  template = "./instance_creation.j2"
  context {

    type = "yaml"
    data = yamlencode({ 
      instances = local.yaml_file.instances
      settings = local.yaml_file.settings
    })
  }
}

# Prepare jinja template for disk creation block
data "jinja_template" "disk_creation" {
  template = "./disk_creation.j2"
  context {

    type = "yaml"
    data = yamlencode({ 
      instances = local.yaml_file.instances
    })
  }
}

# Prepare jinja template for disk attachment block
data "jinja_template" "disk_attachment" {
  template = "./disk_attachment.j2"
  context {

    type = "yaml"
    data = yamlencode({ 
      instances = local.yaml_file.instances
      volume_id = local.yaml_file.volume_id
    })
  }
}

# Create an instance for each defined instance in data.yaml
resource "aws_instance" "ec2_instances" {
  for_each = {for k, v in yamldecode(data.jinja_template.instance_creation.result) : k => v }
  ami           =  each.value.ami 
  instance_type = each.value.type 
  availability_zone = each.value.az 
  tags = {
    Name = each.value.name 
  }
  key_name      = each.value.key  
  vpc_security_group_ids = [aws_security_group.ssh_group.id]
}

# Creates a volume for each instance as defined in data.yaml
resource "aws_ebs_volume" "ebs_volumes" {
  for_each = {for k, v in yamldecode(data.jinja_template.disk_creation.result) : k => v }
  availability_zone = each.value.az
  size = each.value.size
  tags = {
    Name = each.value.disk_name
  }
}

# Attach each volume to its corresponding instance 
resource "aws_volume_attachment" "volume_attachment" {
  for_each = {for k, v in yamldecode(data.jinja_template.disk_attachment.result) : k => v }
  instance_id = aws_instance.ec2_instances[each.value.instance_id].id
  device_name = each.value.dev_name
  volume_id = join(",", [for k, v in aws_ebs_volume.ebs_volumes : v.id if v.tags.Name == each.value.volume_id])

  depends_on = [
    aws_instance.ec2_instances,
    aws_ebs_volume.ebs_volumes
  ]
   }

  