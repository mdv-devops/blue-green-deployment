
output "load_balancer_url" {
  value = aws_lb.lb.dns_name
}
