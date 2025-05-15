output "lb_arns" {
  value = {
    for k,v in var.app_lbs: k => aws_lb.app[k].arn
  }
}

output "lbs" {
  value = aws_lb.app
}