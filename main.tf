# Define the AWS provider with the specified region.
provider "aws" {
  region = var.aws_region
}

# Create AWS EC2 instances based on the provided parameters.
resource "aws_instance" "ec2_instances" {
  # Create instances based on the length of the instance names list.
  count = length(var.instance_names)

  # Specify the Amazon Machine Image (AMI) ID for the instances.
  ami = var.ami_id

  # Specify the type of EC2 instances to launch.
  instance_type = var.instance_type

  # Distribute instances across different availability zones.
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  # Assign names to each instance using values from the instance names list.
  tags = {
    Name = var.instance_names[count.index]
  }
}

# Create AWS EBS volumes based on the provided parameters.
resource "aws_ebs_volume" "ebs_volumes" {
  # Create volumes for each instance
  count = length(var.instance_names) * length(var.disk_sizes)

  # Assign availability zones to corresponding volumes.
  availability_zone = aws_instance.ec2_instances[floor(count.index / length(var.disk_sizes))].availability_zone

  # Assign sizes to volumes.
  size = var.disk_sizes[floor(count.index % length(var.disk_sizes))]
}

# Attach EBS volumes to EC2 instances based on the provided parameters.
resource "aws_volume_attachment" "attach_ebs" {
  # Attach volumes to instances for each instance and disk size combination.
  count = length(var.instance_names) * length(var.disk_sizes)

  # Specify the device name for each attached volume.
  device_name = var.device_name[floor(count.index % length(var.disk_sizes))]

  # Specify the instance ID for each attached volume.
  instance_id = aws_instance.ec2_instances[floor(count.index / length(var.disk_sizes))].id

  # Specify the volume ID for each attached volume.
  volume_id = aws_ebs_volume.ebs_volumes[count.index].id
}