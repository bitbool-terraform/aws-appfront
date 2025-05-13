resource "aws_security_group" "out" {
  for_each =  local.net_outgoing_sgs

  name        = format("%s-%s-out-%s",var.project,var.systemenv,each.key)
  description = format("%s-%s-out-%s",var.project,var.systemenv,each.key)
  vpc_id      = local.vpc_id

  dynamic "egress" {
    for_each = each.value
    content {
      from_port       = lookup(egress.value,"port",lookup(egress.value,"from_port","INVALID"))
      to_port         = lookup(egress.value,"port",lookup(egress.value,"to_port","INVALID"))
      protocol        = lookup(egress.value,"proto",-1)
      cidr_blocks     = lookup(egress.value,"range",["0.0.0.0/0"])
      description     = egress.key
    }
  }

  tags = merge( {Name = format("%s-%s-out-%s",var.project,var.systemenv,each.key)}, local.tags_module_sgs  )
}

resource "aws_security_group" "in" {
  for_each =  local.net_incoming_sgs

  name        = format("%s-%s-in-%s",var.project,var.systemenv,each.key)
  description = format("%s-%s-in-%s",var.project,var.systemenv,each.key)
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = each.value
    content {
      from_port       = lookup(ingress.value,"port",lookup(ingress.value,"from_port","INVALID"))
      to_port         = lookup(ingress.value,"port",lookup(ingress.value,"to_port","INVALID"))
      protocol        = lookup(ingress.value,"proto",-1)
      cidr_blocks     = lookup(ingress.value,"range",["0.0.0.0/0"])
      description     = ingress.key
    }
  }

  tags = merge( {Name = format("%s-%s-in-%s",var.project,var.systemenv,each.key)}, local.tags_module_sgs)
}

# resource "aws_security_group" "appsrvGroup" {
#   for_each =  var.appsrvGroups 
  
#   name        = format("%s-%s-appsrvGroup-%s", var.project, var.systemenv,each.value.name )
#   description = format("%s-%s-appsrvGroup-%s", var.project, var.systemenv,each.value.name )
#   vpc_id      = local.vpc_id

#   tags = merge( {Name = format("%s-%s-appsrvGroup-%s", var.project, var.systemenv,each.value.name )}, local.tags_module_sgs)
# }

# resource "aws_security_group" "appsrvall" {

#   name        = format("%s-%s-appsrv-all", var.project, var.systemenv )
#   description = format("%s-%s-appsrv-all", var.project, var.systemenv )
#   vpc_id      = local.vpc_id

#   tags = merge( {Name = format("%s-%s-appsrv-all", var.project, var.systemenv )}, local.tags_module_sgs)
# }

# resource "aws_security_group" "dbsrvGroup" {
#   for_each =  var.dbsrvGroups 

#   dynamic "ingress" {
#     for_each = merge([for sg in each.value.sgs.in: local.net_incoming_sgs[sg]]... )
#     content {
#       from_port       = lookup(ingress.value,"port",lookup(ingress.value,"from_port","INVALID"))
#       to_port         = lookup(ingress.value,"port",lookup(ingress.value,"to_port","INVALID"))
#       protocol        = lookup(ingress.value,"proto",-1)
#       cidr_blocks     = lookup(ingress.value,"range",["0.0.0.0/0"])
#       description     = ingress.key
#     }
#   }

#   dynamic "egress" {
#     for_each = merge([for sg in each.value.sgs.out: local.net_outgoing_sgs[sg]]... )
#     content {
#       from_port       = lookup(egress.value,"port",lookup(egress.value,"from_port","INVALID"))
#       to_port         = lookup(egress.value,"port",lookup(egress.value,"to_port","INVALID"))
#       protocol        = lookup(egress.value,"proto",-1)
#       cidr_blocks     = lookup(egress.value,"range",["0.0.0.0/0"])
#       description     = egress.key
#     }
#   }

#   name        = format("%s-%s-dbsrvGroup-%s", var.project, var.systemenv,each.value.name )
#   description = format("%s-%s-dbsrvGroup-%s", var.project, var.systemenv,each.value.name )
#   vpc_id      = local.vpc_id

#   tags = merge( {Name = format("%s-%s-dbsrvGroup-%s", var.project, var.systemenv,each.value.name )}, local.tags_module_sgs)
# }

# resource "aws_security_group" "dbsrvall" {

#   name        = format("%s-%s-dbsrv-all", var.project, var.systemenv )
#   description = format("%s-%s-dbsrv-all", var.project, var.systemenv )
#   vpc_id      = local.vpc_id

#   tags = merge( {Name = format("%s-%s-dbsrv-all", var.project, var.systemenv )}, local.tags_module_sgs)
# }





