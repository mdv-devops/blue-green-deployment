variable "creator" {
  type    = string
  default = "MDV-devops"
}

variable "name" {
  description = "Name of environment"
  type        = string
  default     = "Test"
}

variable "key_name" {
  description = "Private key name to use with instance"
  type        = string
  default     = "Key_Virginia"
}

variable "ingress_ports" {
  description = "Ports for SG"
  type        = list(string)
  default     = ["22", "80", "443"]
}

variable "instance_type" {
  description = "AWS instance type"
  type        = string
  default     = "t2.micro"
}

variable "tags" {
  type = map(string)
  default = {
    Owner       = "MDV-devops"
    Environment = "Test"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cidr_block" {
  description = "cidr block in prod VPC"
  default     = "10.10.0.0/16"
}

variable "public_a" {
  description = "cidr block in public subnet A"
  default     = "10.10.10.0/24"
}

variable "public_b" {
  description = "cidr block in public subnet B"
  default     = "10.10.11.0/24"
}

variable "domain_name" {
  default = "mdv-devops.ml"
}

variable "ssh_port" {
  default = "443"
}

variable "http_port" {
  default = "80"
}
