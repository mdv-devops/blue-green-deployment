terraform {
  backend "s3" {
    bucket = "mdv-devops-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

#===============================================================================

#============================= Create VPC ======================================

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-VPC" })
}

#=========================== Create Subnets ====================================

resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_a
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "${var.name}-public-subnet-A" })
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_b
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = merge(var.tags, { Name = "${var.name}-public-subnet-B" })
}

#======================= Create Internet Gateway ===============================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.tags, { Name = "${var.name}-Internet Gateway" })
}

#=========================== Create Route Tables ===============================

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, { Name = "${var.name}-Route Table" })
}

#============================= Assosiate Routes ================================

resource "aws_route_table_association" "internet_access_public_subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "internet_access_public_subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.rt.id
}

#=========================== Create Security Group =============================

resource "aws_security_group" "sg" {
  name        = "${var.creator}-SecurityGroup"
  description = "Allow TLS & SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-Security Group" })
}

#======================== Create Launch Configuration ==========================

resource "aws_launch_configuration" "lc" {
  name_prefix                 = "LC-"
  image_id                    = data.aws_ami.latest_amazon_linux_ami.id
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.sg.id]
  associate_public_ip_address = true
  user_data                   = file("data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#======================== Create Autoscaling Group =============================

resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.name}-ASG-${aws_launch_configuration.lc.name}"
  launch_configuration      = aws_launch_configuration.lc.name
  target_group_arns         = [aws_lb_target_group.default_tg.arn]
  min_size                  = 2
  max_size                  = 2
  health_check_type         = "ELB"
  min_elb_capacity          = 2
  vpc_zone_identifier       = data.aws_subnet_ids.public_subnet.ids
  wait_for_capacity_timeout = "3m"

  dynamic "tag" {
    for_each = {
      Name  = "${var.name} server created by ASG"
      Owner = var.creator
      Stage = var.name
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

#=========================== Create Load Balancer ==============================

resource "aws_lb" "lb" {
  name               = "${var.name}-LoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = data.aws_subnet_ids.public_subnet.ids
  tags               = merge(var.tags, { Name = "${var.name}-Load Balancer" })
}


#------------------- Create target group for load balancer ---------------------

resource "aws_lb_target_group" "default_tg" {
  name     = "${var.name}-DefaultTargetGroup"
  port     = var.http_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/index.html"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
  }

  tags = merge(var.tags, { Name = "${var.name}-Default Target Group" })
}

#-------------------- Create listeners for load balancer -----------------------

resource "aws_lb_listener" "ssl_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = var.ssh_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "ssl_rule" {
  listener_arn = aws_lb_listener.ssl_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_tg.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

#======================= Create Route53 Record =================================

resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}
