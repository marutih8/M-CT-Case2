variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to use"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for ALB and EC2"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS ALB listener"
  type        = string
}

variable "domain_name" {
  description = "Domain name used in Route53 or SSL cert"
  type        = string
}

