## Terraform AWS Infrastructure Provisioning

This Terraform script provisions AWS EC2 instances with attached EBS volumes. It is designed to be flexible and configurable to accommodate any number of instances, any number of disks per instance, and multiple availability zones.

### Prerequisites

Before using this Terraform script, ensure you have the following variables defined:

- **aws_region**: AWS region where resources will be provisioned. 

- **instance_names**: List of instance names. 

- **ami_id**: AMI ID for the EC2 instance. (e.g., "ami-0e731c8a588258d0d")

- **instance_type**: Type of EC2 instance. (e.g., "t2.micro")

- **disk_sizes**: Sizes of additional disks to attach to the EC2 instance. Specify sizes in GB. (e.g., [10, 20, 15])

- **availability_zones**: List of availability zones. 

- **device_name**: List of device names for the attached disks. 

### Usage

1. Create the variables in `variables.tf` file to suit your requirements.
2. Initialize the Terraform workspace: `terraform init`.
3. Review the execution plan: `terraform plan`.
4. Apply the changes: `terraform apply`.

### Note

- Ensure that you have appropriate permissions and credentials set up to provision resources in your AWS account.
- Review the Terraform documentation for more details on advanced configurations and best practices.