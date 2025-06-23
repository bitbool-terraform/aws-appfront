variable "systemenv" { type = string }
#variable "cluster_tag" { type = string }
variable "aws_region" { type = string }

variable "base_workspace" { type = string }
variable "waf_workspace" { default = null }

#variable "app_servers" {}
#variable "appsrvGroups" {}

#variable "db_servers" {}
#variable "dbsrvGroups" {}

# variable "accelerators" {}
# variable "cloudfronts" {}
variable "app_lbs" {}
variable "apps" {}
variable "existing_lb_target_groups" {}
variable "app_lb_target_groups" {}
variable "app_lb_associations" {}
variable "app_lb_rules" {}
variable "app_lb_ssl_policy_default" {}

variable "dns_zone_internal" { type = string }
variable "route53_app_zones" {}
variable "maintenance_page" { type = string }
variable "welcome_page" { type = string }

variable "app_certificates" {}

variable "waf_arns" { default = {} }

#variable "db_volumes" {}
#variable "db_volumes_attachments" {}


# variable "alarms_cpu_period" { default = 60 }
# variable "alarms_cpu_evaluation" { default = 2 }
# variable "alarms_cpu_threshold" { default = 80 }
# variable "alarms_storageFree_period" { default = 60 }
# variable "alarms_storageFree_evaluation" { default = 2 }
# variable "alarms_storageFree_threshold" { default = 20 }
# variable "alarms_memUsed_period" { default = 60 }
# variable "alarms_memUsed_evaluation" { default = 2 }
# variable "alarms_memUsed_threshold" { default = 80 }
# variable "alarms_connections_period" { default = 60 }
# variable "alarms_connections_evaluation" { default = 2 }
# variable "alarms_connections_threshold" { default = 30 }