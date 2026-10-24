variable "aws_region" {
  description = "AWS region for the demo"
  type        = string
  default     = "ap-southeast-2"
}

variable "availability_zone" {
  description = "Single Availability Zone"
  type        = string
  default     = "ap-southeast-2a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
  default     = "Terraform"
}

variable "ami_id" {
  description = "Ubuntu AMI ID in ap-southeast-2"
  type        = string
  default     = "ami-0312bcacbe51d03c8"
}
