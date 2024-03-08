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
  template = "./templates/instance_creation.j2"
  context {

    type = "yaml"
    data = yamlencode({ 
      instances = local.yaml_file.instances
      settings = local.yaml_file.settings
    })
  }
}

# Prepare jinja template for disk creation block
data "jinja_template" "disk_create_attach" {
  template = "./templates/disk_create_attach.j2"
  context {

    type = "yaml"
    data = yamlencode({ 
      instances = local.yaml_file.instances
      settings = local.yaml_file.settings
      letters = local.yaml_file.letters
    })
  }
}

/*
resource "local_file" "create_manipulated_yaml_file" {
   content  = data.jinja_template.disk_create_attach.result
   filename = "./ansible_data.yml"
}
*/

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
  for_each = {for k, v in yamldecode(data.jinja_template.disk_create_attach.result) : k => v }
  availability_zone = each.value.az
  size = each.value.size
  tags = {
    Name = each.value.disk_name
    Dev_name = join(",", each.value.dev_name)
  }
}

# Attach each volume to its corresponding instance 
resource "aws_volume_attachment" "volume_attachment" {
  for_each = {for k, v in yamldecode(data.jinja_template.disk_create_attach.result) : k => v }
  instance_id = aws_instance.ec2_instances[each.value.instance].id
  device_name = join(",", each.value.dev_name)
  volume_id = join(",", [for k, v in aws_ebs_volume.ebs_volumes : v.id if v.tags.Name == each.value.disk_name])

  depends_on = [
    aws_instance.ec2_instances,
    aws_ebs_volume.ebs_volumes
  ]
   }


locals {
  instance_mapping = [
    for instance in aws_instance.ec2_instances : {
      public_ip      = instance.public_ip
      block_devices  = [
        for device in instance.ebs_block_device : {
          device_name   = device.tags.Dev_name
          name     = device.tags.Name
        }
      ]
    }
  ]
}

output "test" {
  value = local.instance_mapping
}


data "template_file" "ansible_inventory" {
  template = templatefile("${path.module}/hosts.tpl", {
    instance_info = local.instance_mapping
  })
}

resource "null_resource" "save_inventory" {
  triggers = {
    content = data.template_file.ansible_inventory.rendered
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${data.template_file.ansible_inventory.rendered}' > ansible_inventory.ini
    EOT
  }
}







