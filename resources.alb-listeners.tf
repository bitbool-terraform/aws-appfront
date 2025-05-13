
resource "aws_lb_listener" "app" {
  for_each = { for v in local.all_lb_listeners: v.key => v if lookup(v,"enabled",true) }

  # depends_on = [
  #   aws_acm_certificate.app
  # ]
  load_balancer_arn = aws_lb.app[each.value.lb].arn
  
  port              = lookup(each.value,"port",(lookup(each.value,"protocol","HTTPS") == "HTTPS" ? 443 : 80))
  protocol          = lookup(each.value,"protocol","HTTPS")
  ssl_policy        = lookup(each.value,"ssl_policy",(lookup(each.value,"protocol","HTTPS") == "HTTPS" ? var.app_lb_ssl_policy_default : null))
  certificate_arn   = lookup(each.value,"protocol","HTTPS") == "HTTPS" ? data.aws_acm_certificate.app[each.value.certificates[0]].arn : null

  # default_action {
  #   type = "fixed-response"

  #   fixed_response {
  #     content_type = "text/plain"
  #     message_body = "Welcome"
  #     status_code  = "200"
  #   }
  # }

  dynamic "default_action" {
    for_each = { for v in each.value.default_actions: lookup(v,"key",v.type) => v if v.type == "redirect" }
    content {
      type = "redirect"

      redirect {
        status_code = lookup(default_action.value.redirect,"status_code","HTTP_301")

        host        = lookup(default_action.value.redirect,"host",null)
        path        = lookup(default_action.value.redirect,"path",null)
        port        = lookup(default_action.value.redirect,"port",null)      
        protocol    = lookup(default_action.value.redirect,"protocol",null)
        query       = lookup(default_action.value.redirect,"query",null)      
      }
    }
  }

  dynamic "default_action" {
    for_each = { for v in each.value.default_actions: lookup(v,"key",v.type) => v if v.type == "fixed-response" }
    content {
      type = "fixed-response"

      fixed_response {
        content_type = lookup(default_action.value.fixed_response,"content_type","text/html")

        status_code  = lookup(default_action.value.fixed_response,"status_code",200)
        message_body = lookup(default_action.value.fixed_response,"message_body",null)
      }
    }
  }  

  dynamic "default_action" {
    for_each = { for v in each.value.default_actions: lookup(v,"key",v.type) => v if v.type == "forward" }
    content {
      type = "forward"

      forward {
        dynamic "target_group" {
          for_each = default_action.value.targets
          content {
            arn = local.all_lb_target_groups_arns[target_group.key]
          }
        }
        stickiness {
          enabled  = lookup(lookup(default_action.value,"stickiness",{}),"enabled",true)
          duration = lookup(lookup(default_action.value,"stickiness",{}),"duration",600)
        }      
      }
    }
  }  

  tags = merge( { Name = format("%s-%s-%s",var.project,var.systemenv,each.value.name)}, local.tags_module_alb)

}

locals {
  app_lb_extra_certs = flatten([
    for v in local.all_lb_listeners: [ 
      for c in slice(v.certificates,1,length(v.certificates)): [
          { key = "${format("%s-%s",v.key,c)}", cert = c, lb = v.key }
        ] if !lookup(var.app_certificates[c],"existing",false)
      ] if lookup(v,"enabled",true) && length(lookup(v,"certificates",[]))>1
  ])
  
  app_lb_extra_certs_existing = flatten([
    for v in local.all_lb_listeners: [ 
      for c in slice(v.certificates,1,length(v.certificates)): [
          { key = "${format("%s-%s",v.key,c)}", cert = c, lb = v.key }
        ] if lookup(var.app_certificates[c],"existing",false)
      ] if lookup(v,"enabled",true) && length(lookup(v,"certificates",[]))>1
  ])  
}

resource "aws_lb_listener_certificate" "app" {
  for_each = { for v in local.app_lb_extra_certs: v.key => v } 

  listener_arn    = aws_lb_listener.app[each.value.lb].arn
  certificate_arn = aws_acm_certificate.app[each.value.cert].arn
}

resource "aws_lb_listener_certificate" "app_existing" {
  for_each = { for v in local.app_lb_extra_certs_existing: v.key => v } 

  listener_arn    = aws_lb_listener.app[each.value.lb].arn
  certificate_arn = data.aws_acm_certificate.app[each.value.cert].arn
}


resource "aws_lb_listener_rule" "app" {
  for_each = { for v in local.all_lb_rules: v.key => v if lookup(v,"enabled",true) }

  listener_arn = aws_lb_listener.app[each.value.listener].arn
  priority     = each.value.priority

  dynamic "action" {
    for_each = { for v in each.value.actions: lookup(v,"key",v.type) => v if v.type == "redirect" }
    content {
      type = "redirect"

      redirect {
        status_code = lookup(action.value.redirect,"status_code","HTTP_301")

        host        = lookup(action.value.redirect,"host",null)
        path        = lookup(action.value.redirect,"path",null)
        port        = lookup(action.value.redirect,"port",null)      
        protocol    = lookup(action.value.redirect,"protocol",null)
        query       = lookup(action.value.redirect,"query",null)      
      }
    }
  }

  dynamic "action" {
    for_each = { for v in each.value.actions: lookup(v,"key",v.type) => v if v.type == "fixed-response" }
    content {
      type = "fixed-response"

      fixed_response {
        content_type = lookup(action.value.fixed_response,"content_type","text/html")

        status_code  = lookup(action.value.fixed_response,"status_code",200)
        message_body = lookup(action.value.fixed_response,"message_body",null)
      }
    }
  }  

  dynamic "action" {
    for_each = { for v in each.value.actions: lookup(v,"key",v.type) => v if v.type == "forward" }
    content {
      type = "forward"
      #target_group_arn = length(keys(action.value.targets)) == 1 ? (lookup(action.value,"target_is_server",false) ? aws_lb_target_group.server[keys(action.value.targets)[0]].arn : local.all_lb_target_groups_arns[keys(action.value.targets)[0]].arn) : "lala"
      #target_group_arn = "arn:aws:elasticloadbalancing:eu-south-1:159831495814:targetgroup/awseb-atlas-pr-default-3ycxu/20b3f307479c4c8c" 
      target_group_arn = length(keys(action.value.targets)) == 1 ? local.all_lb_target_groups_arns[keys(action.value.targets)[0]] : "lala"      

      dynamic "forward" {
        for_each = length(keys(action.value.targets)) > 1 ? ["enable"] : []
        content {
          dynamic "target_group" {
            for_each = action.value.targets
            content {
              arn = local.all_lb_target_groups_arns[target_group.key]
            }
          }
 
          stickiness {
            enabled  = lookup(lookup(action.value,"stickiness",{}),"enabled",true)
            duration = lookup(lookup(action.value,"stickiness",{}),"duration",600)
          }      
        }
      }
    }
  }  

  dynamic "condition" {
    #for_each = { for v in each.value.conditions: "${index(each.value.conditions,v)}" => v }
    for_each = each.value.conditions
    content {

      dynamic "host_header" {
        for_each = try({"key" = condition.value.host_header},{}) 
        content {
          values = host_header.value
        }
      }

      dynamic "http_header" {
        for_each = try({"key" = condition.value.http_header},{}) 
        #for_each = try({for h in condition.value.http_header: h.http_header_name => h },{}) 
        content {
          http_header_name = lookup(http_header.value,"http_header_name",null)
          values           = lookup(http_header.value,"values",null) 
        }
      }

      dynamic "http_request_method" {
        for_each = try({"key" = condition.value.http_request_method},{}) 
        content {
          values = http_request_method.value
        }
      }

      dynamic "path_pattern" {
        for_each = try({"key" = condition.value.path_pattern},{}) 
        content {
          values = path_pattern.value
        }
      }

      dynamic "query_string" {
        for_each = try({for q in condition.value.query_string: q.key => q },{}) 
        content {
          key = lookup(query_string.value,"key",null)
          value = query_string.value.value
        }
      }

      dynamic "source_ip" {
        for_each = try({"key" = condition.value.source_ip},{}) 
        content {
          values = source_ip.value
        }
      }

    }
  }

  tags = merge( {Name = format("%s-%s",var.systemenv,each.value.name), Rule = format("%s-%s-%s",var.project,var.systemenv,each.value.key)}, local.tags_module_alb)
}


# resource "aws_lb_listener_rule" "host_based_weighted_routing" {
#   listener_arn = aws_lb_listener.front_end.arn
#   priority     = 99

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.static.arn
#   }

#   condition {
#     host_header {
#       values = ["my-service.*.terraform.io"]
#     }
#   }
# }



# locals {
#   lb_listeners_additional_certs_array = flatten([
#     for ln in local.all_lb_listeners: concat([
#         for c in lookup(ln,"certificates",[]) : {
#           key = format("%s-%s",ln.key,c)
#           listener = ln.key
#           cert = aws_acm_certificate.app[c].arn
#         } if lookup(local.certificates[c],"cloudfront",false) == false && index(lookup(ln,"certificates",[]),c)>0
#        ],[
#         for c in lookup(ln,"certificates",[]): {
#           key = format("%s-%s",ln.key,c)
#           listener = ln.key
#           cert = aws_acm_certificate.app-us[c].arn
#         } if lookup(local.certificates[c],"cloudfront",false) && index(lookup(ln,"certificates",[]),c)>0
#       ])
#     if lookup(ln,"enabled",true)
#   ])

#   lb_listeners_additional_certs = {
#     for c in local.lb_listeners_additional_certs_array: 
#       c.key => c
#   } 
# }

# resource "aws_lb_listener_certificate" "app" {
#   for_each = local.lb_listeners_additional_certs

#   listener_arn    = aws_lb_listener.app[each.value.listener].arn
#   certificate_arn = each.value.cert
# }
