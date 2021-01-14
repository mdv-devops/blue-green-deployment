data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_ami" "latest_amazon_linux_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
data "aws_acm_certificate" "cert" {
  domain = "*.${var.domain_name}"
}
data "aws_vpc" "vpc_id" {
  id = aws_vpc.vpc.id
}
data "aws_subnet_ids" "public_subnet" {
  vpc_id = data.aws_vpc.vpc_id.id
}
