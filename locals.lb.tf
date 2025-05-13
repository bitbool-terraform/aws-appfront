# # listener action examples
#         actions_specs = [
#           #{ type = "redirect", redirect = { host = "otherurl.com"} },
#           { template = "redirect2https" },
#           #{ template = "static_html", fixed_response = { message_body = "lala" } }
#           #{ template = "maintenance" }
#           #{ type = "forward", targets = { "transportVappMain2" = { weight = 500 } } } 
#           #{ type = "forward", targets = { "transportVappMain" = {} } } 
#         ]

# output "all_lb_rules" {
#   value = local.all_lb_rules
# }

locals {


  all_lb_target_groups_arns = merge(
    {
      for k,v in data.aws_lb_target_group.existing: k => v.arn
    },
    {
      for k,v in aws_lb_target_group.app: k => v.arn
    },
  )
   
  all_lb_rules = flatten([
      for assock,assocv in var.app_lb_associations: [
        for listener in lookup(assocv,"listeners",["https"]): concat([
          for rule in var.app_lb_rules[assocv.rules]: 
           merge(
              {
                key = format("%s-%s-%s-%s",assocv.balancer,assocv.app,listener,rule.name)
                priority = (assocv.order*1000)+lookup(rule,"order",(index(var.app_lb_rules[assocv.rules],rule)+1)*10)
                lb = assocv.balancer
                listener = format("%s-%s",assocv.balancer,listener)
                appkey = assocv.app
                actions = [ for a in rule.actions_specs: merge(lookup(local.app_action_templates[assocv.app],lookup(a,"template",""),{}),a) ]
                conditions = flatten([ 
                    [for c in lookup(rule,"condition_specs",[]): merge(lookup(local.app_condition_templates[assocv.app],lookup(c,"template",""),{}),c) ],
                    (lookup(rule,"do_not_limit_to_my_urls",false) || lookup(rule.actions_specs[0],"template",null) == "aliases") ? [] : [local.app_condition_templates[assocv.app].myurls]
                  ])
              }, 
              rule) if lookup(rule,"enabled",true)
          ],[
          for server in lookup(var.app_lb_target_groups,var.apps[assocv.app].targetgroup,{servers_all=[]}).servers_all: 
          {
            key = format("%s-%s-%s-%s",assocv.balancer,assocv.app,listener,server)
            priority = (assocv.order*1000)-100+index(var.app_lb_target_groups[var.apps[assocv.app].targetgroup].servers_all,server)+1
            lb = assocv.balancer
            listener = format("%s-%s",assocv.balancer,listener)
            appkey = assocv.app
            actions = [{ type = "forward", targets = { "${format("%s-%s",var.apps[assocv.app].targetgroup,server)}" = {}  },target_is_server = true }]
            conditions = [{host_header = [for u in local.internal_urls_server_by_app[assocv.app]: u.url if u.server == server ]}]        
          } if lookup(assocv,"rules_each_server",false)
        ]) 
      ] if lookup(assocv,"enabled",true)
    ])

  app_lb_target_group_attachments_live = flatten([
      for groupk,groupv in var.app_lb_target_groups: [
        for server in groupv.servers_live : merge({
          key = format("%s-%s",groupk,server)
          server = server
          group = groupk  
        },groupv)
      ]
    ])

  app_lb_target_group_attachments_all = flatten([
      for groupk,groupv in var.app_lb_target_groups: [
        for server in groupv.servers_all : merge({
          key = format("%s-%s",groupk,server)
          server = server
          group = groupk  
        },groupv)
      ]
    ])

  all_lb_listeners = flatten([
    for lbk, lbv in var.app_lbs: [
      for lnk, lnv in lbv.listeners: merge(lnv,{ 
        key = format("%s-%s",lbk,lnk), 
        lb = lbk, 
        default_actions = [ for a in lnv.actions_specs: merge(lookup(local.lb_action_templates,lookup(a,"template",""),{}),a) ]
        }
      )
    ]
  ])

  lb_action_templates = {
    redirect_302 = {
      type = "redirect"
      redirect = {
          status_code = "HTTP_302"
      }
    }  
    redirect2https = {
      type = "redirect"
      redirect = {
          status_code = "HTTP_301"
          port        = 443
          protocol    = "HTTPS"
      }
    }
    static_html = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        status_code  = 200
      }
    }
    maintenance = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        status_code  = 200
        message_body = file(var.maintenance_page)
      }
    }
    welcome = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        status_code  = 200
        message_body = file(var.welcome_page)
      }
    }  
    not_welcome = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        status_code  = 400
        message_body = "blocked"
      }
    }      
    health = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        status_code  = 200
        message_body = "LB is UP"
      }
    }    
    forward_nonsticky = {
      type = "forward"
      stickiness ={
        enabled  = false
        duration = 600
      }
    }
    deny = {
      type = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        status_code  = 403
        message_body = "Forbidden"
      }
    }        
  }

  app_condition_templates = {
    for appK, appV  in var.apps : 
      appK => {
        aliases = {
          host_header = appV.aliases
        }
        myurls = {
          host_header = concat(appV.urls,try([local.internal_url_main_by_app[appK].url],[])) 
        }
        mainurls = {
          host_header = appV.urls
        }        
        health = {
          path_pattern = lookup(appV,"health_page",["/health"])
        }
        developers = {
          source_ip = lookup(appV,"acl_developers",local.net_acls_groups["developers_global"])
        }
      }
  }

  app_action_templates = {
    for appK, appV  in var.apps : 
      appK => merge(
        local.lb_action_templates,
        {
          aliases = {
            type = "redirect"
            redirect = {
              status_code = "HTTP_301"
              host = var.apps[appK].urls[0]
            }
          }          
          maintenance = {
            type = "fixed-response"
            fixed_response = {
              content_type = "text/html"
              status_code  = 200
              message_body = file(lookup(var.apps[appK],"maintenance_page",var.maintenance_page))
            }
          }
          welcome = {
            type = "fixed-response"
            fixed_response = {
              content_type = "text/html"
              status_code  = 200
              message_body = file(lookup(var.apps[appK],"welcome_page",var.welcome_page))
            }
          }
          default = {
            type = "forward"
            targets = { "${appV.targetgroup}" = {} }
          }
        }
      )
  }

}

# output "all_lb_rules" {
#   value = local.all_lb_rules
# }