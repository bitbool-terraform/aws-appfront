output "existing_targets" {
  value = var.existing_lb_target_groups
}



data "aws_lb_target_group" "existing" {
  for_each = var.existing_lb_target_groups

  tags = lookup(each.value,"tags",null)
  arn = lookup(each.value,"arn",null)
  name = lookup(each.value,"name",null)
}


resource "aws_lb_target_group" "app" {
  for_each = var.app_lb_target_groups

  name     = substr(format("%s-%s-%s",var.project,var.systemenv,each.value.name),0,32)
  vpc_id   = local.vpc_id
  ip_address_type = "ipv4"
  target_type = "instance"

  protocol = "HTTP"
  protocol_version = "HTTP1"
  proxy_protocol_v2 = false
  port     = lookup(each.value,"port",80)

  load_balancing_algorithm_type = "least_outstanding_requests"
  #slow_start = 30

  health_check {
    enabled = true #lookup(lookup(each.value,"health_check",{}),"enabled",false)
    healthy_threshold = lookup(lookup(each.value,"health_check",{}),"healthy_threshold",2)
    unhealthy_threshold = lookup(lookup(each.value,"health_check",{}),"unhealthy_threshold",5)
    interval = lookup(lookup(each.value,"health_check",{}),"interval",60)
    path = lookup(lookup(each.value,"health_check",{}),"path","/")
    port = lookup(lookup(each.value,"health_check",{}),"port",80)
    protocol = lookup(lookup(each.value,"health_check",{}),"protocol","HTTP")
    timeout = lookup(lookup(each.value,"health_check",{}),"timeout",10)
    matcher = lookup(lookup(each.value,"health_check",{}),"matcher","200-299")
  }
  stickiness {
    enabled = lookup(lookup(each.value,"stickiness",{}),"enabled",true)
    cookie_duration = lookup(lookup(each.value,"stickiness",{}),"cookie_duration",86400)
    type = lookup(lookup(each.value,"stickiness",{}),"type","lb_cookie")
  }

  tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.value.name)}, local.tags_module_alb)

}

# resource "aws_lb_target_group_attachment" "app" {
#   for_each = { for v in local.app_lb_target_group_attachments_live: v.key => v }

#   target_group_arn = aws_lb_target_group.app[each.value.group].arn
#   target_id        = aws_instance.appsrv[each.value.server].id
# }



# resource "aws_lb_target_group" "server" {
#   for_each = { for v in local.app_lb_target_group_attachments_all: v.key => v }

#   name     = substr(format("%s-%s-%s-%s",var.project,var.systemenv,each.value.name,each.value.server),0,32)
#   vpc_id   = local.vpc_id
#   ip_address_type = "ipv4"
#   target_type = "instance"

#   protocol = "HTTP"
#   protocol_version = "HTTP1"
#   proxy_protocol_v2 = false
#   port     = lookup(each.value,"port",80)

#   load_balancing_algorithm_type = "least_outstanding_requests"
#   #slow_start = 30

#   health_check {
#     enabled = true #lookup(lookup(each.value,"health_check",{}),"enabled",false)
#     healthy_threshold = lookup(lookup(each.value,"health_check",{}),"healthy_threshold",2)
#     unhealthy_threshold = lookup(lookup(each.value,"health_check",{}),"unhealthy_threshold",5)
#     interval = lookup(lookup(each.value,"health_check",{}),"interval",60)
#     path = lookup(lookup(each.value,"health_check",{}),"path","/")
#     port = lookup(lookup(each.value,"health_check",{}),"port",80)
#     protocol = lookup(lookup(each.value,"health_check",{}),"protocol","HTTP")
#     timeout = lookup(lookup(each.value,"health_check",{}),"timeout",10)
#     matcher = lookup(lookup(each.value,"health_check",{}),"matcher","200-299")
#   }
#   stickiness {
#     enabled = lookup(lookup(each.value,"stickiness",{}),"enabled",true)
#     cookie_duration = lookup(lookup(each.value,"stickiness",{}),"cookie_duration",86400)
#     type = lookup(lookup(each.value,"stickiness",{}),"type","lb_cookie")
#   }

#   tags = merge( {Name = format("%s-%s-%s-%s",var.project,var.systemenv,each.value.name,each.value.server)}, local.tags_module_alb)

# }

# resource "aws_lb_target_group_attachment" "server" {
#   for_each = { for v in local.app_lb_target_group_attachments_all: v.key => v }

#   target_group_arn = aws_lb_target_group.server[each.key].arn
#   target_id        = aws_instance.appsrv[each.value.server].id
# }
