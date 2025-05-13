# output test {
#   value = local.app_servers_zone
# }

# output test2 {
#   value = local.internal_urls_server_by_app
# }

locals {

  # vm_specs = {
  #   "app" = {
  #     "size" = "c6i.xlarge"
  #     "ami" = "win2022-20230215"
  #     "associate_public_ip_address" = false
  #     "detailed_monitoring" = true
  #     "subnet" = "dmz"
  #     "root_size" = 100
  #     "sgs" = [ aws_security_group.out["all"].id,aws_security_group.in["all"].id]
  #     "init_file" = "neverchanges"      
  #   }
  #   "db" = {
  #     "size" = "t3.medium"
  #     "ami" = "win2022-20230215"
  #     "associate_public_ip_address" = false
  #     "detailed_monitoring" = true
  #     "subnet" = "private"
  #     "root_size" = 100
  #     "sgs" = []#, aws_security_group.out["http"].id, aws_security_group.in["httpApps"].id, ]
  #     "init_file" = "db-alwaysruns"
  #   }    
  # }

  # app_servers = {
  #   for k,v in var.app_servers: k => merge(local.vm_specs[v.specs], v)
  # }

  # app_servers_zone = {
  #   for k,v in local.app_servers: k => lookup(v,"zone",keys(data.terraform_remote_state.base.outputs.azs[v.subnet])[v.index%length(data.terraform_remote_state.base.outputs.azs[v.subnet])])
  # }

  # app_servers_placement = {
  #   for k,v in local.app_servers: k => {
  #     "az" = data.terraform_remote_state.base.outputs.azs[v.subnet][local.app_servers_zone[k]],
  #     "subnet_id" = data.terraform_remote_state.base.outputs.subnet_ids_by_az[v.subnet][local.app_servers_zone[k]]
  #     "ip" = cidrhost(data.terraform_remote_state.base.outputs.subnet_cidr_by_az[v.subnet][local.app_servers_zone[k]],101+v.index)
  #   }
  # }

  lb_subnets = {
    for k,v in var.app_lbs: k => [for z in v.zones: var.subnet_ids_by_az[v.subnet][z] ]
  }

  main_urls_all = flatten([
      for appK,appV in var.apps: [
        for lb_assoc in  var.app_lb_associations : concat(
          [
            for url in appV.urls :
              {
                url = url
                key = url
                cname = aws_lb.app[lb_assoc.balancer].dns_name
                app = appK
                balancer = lb_assoc.balancer
                zone = appV.route53_urls_balancer_app_zone
              }          
          ],
          [
            for url in appV.aliases :
              {
                url = url
                key = url
                cname = aws_lb.app[lb_assoc.balancer].dns_name
                app = appK
                balancer = lb_assoc.balancer
                zone = appV.route53_urls_balancer_app_zone                
              }          
          ]
        ) if lb_assoc.app == appK  
      ]
    ])

  internal_urls_all = flatten([
    for appK,appV in var.apps: [
      for lb_assoc in  var.app_lb_associations : 
        concat(
          [
            for srv in lookup(var.app_lb_target_groups,appV.targetgroup,{servers_all=[]}).servers_all: {
              url = format("%s-%s.%s",appV.url_internal,srv,var.dns_zone_internal)
              key = format("%s-%s",appV.url_internal,srv), 
              cname = aws_lb.app[lb_assoc.balancer].dns_name
              server = srv 
              app = appK
            } 
          ] ,
          [
            {
              url = format("%s.%s",appV.url_internal,var.dns_zone_internal)
              key = format("%s",appV.url_internal), 
              cname = aws_lb.app[lb_assoc.balancer].dns_name
              server = "balanced" 
              app = appK
            }
          ] 
        ) if lb_assoc.app == appK  
      ]
    ])

  internal_urls_all_by_app = {
    for appK,appV in var.apps: appK => [
      for u in local.internal_urls_all: u if u.app == appK
    ]
  }

  internal_url_main_by_app = {
    for appK,appV in var.apps: appK => [ for u in local.internal_urls_all: u if u.app == appK && u.server == "balanced" ][0]
  }

  internal_urls_server_by_app = {
    for appK,appV in var.apps: appK => [
      for u in local.internal_urls_all: u if u.app == appK && u.server != "balanced"
    ]
  }

  # db_servers = {
  #   for k,v in var.db_servers: k => merge(local.vm_specs[v.specs], v)
  # }

  # db_servers_zone = {
  #   for k,v in local.db_servers: k => lookup(v,"zone",keys(data.terraform_remote_state.base.outputs.azs[v.subnet])[v.index%length(data.terraform_remote_state.base.outputs.azs[v.subnet])])
  # }

  # db_servers_placement = {
  #   for k,v in local.db_servers: k => {
  #     "az" = data.terraform_remote_state.base.outputs.azs[v.subnet][local.db_servers_zone[k]],
  #     "subnet_id" = data.terraform_remote_state.base.outputs.subnet_ids_by_az[v.subnet][local.db_servers_zone[k]]
  #     "ip" = cidrhost(data.terraform_remote_state.base.outputs.subnet_cidr_by_az[v.subnet][local.db_servers_zone[k]],101+v.index)
  #   }
  # }

  vpc_id = var.vpc_id
  vpc_cidr = var.vpc_cidr

  backup_tags = var.backup_tags

}

output "internal_urls_all" {
  value = local.internal_urls_all
}
