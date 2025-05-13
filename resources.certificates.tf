####  example certs:
####
# certificates = {
#   platform = {
#     domains = [{
#       zone = var.dns_zone_internal
#       records = ["","*"]
#     }] 
#     aws_issued = true
#   } 
#   transportV = {
#     path = "metaforikoisodinamo.gr"
#   }
#   "self-single" = {
#     domains = [{
#       zone = "awstest.winplatform.grnet.gr"
#       records = ["single"]
#     }] 
#     aws_issued = true
#   }
#   "self-multi" = {
#     domains = [
#       {
#         zone = "awstest.winplatform.grnet.gr"
#         records = ["","test2","sub.sub","*"]
#       },
#       {
#         zone = "lala.gr"
#         records = ["lala1","lala2"]
#       },
#       {
#         zone = "lalawilc.gr"
#         records = ["","lala2","*"]
#       },    
#       ]
#     exlude_from_validation = ["sub.sub.awstest.winplatform.grnet.gr"]     
#     aws_issued = true
#   }
#   app-wildcard = {
#     domains = [{
#       zone = "test.gr"
#       records = ["","*"]
#     }]     
#     aws_issued = true
#   }
#   app-wildsub = {
#     domains = [{
#       zone = "test.gr"
#       records = ["sub","*.sub"]
#     }]         
#     aws_issued = true
#   }  
#   app-singlesub = {
#     domains = [{
#       zone = "test.gr"
#       records = ["sub.sub"]
#     }]         
#     aws_issued = true
#   }    
# }
provider "aws" {
  alias = "us-east-1"
  shared_credentials_files = [ "~/.aws/credentials" ]
  profile    = var.aws_cli_profile
  region     = "us-east-1"
  default_tags {
    tags = {
     "Project" = var.project
     "Project-TFGroup" = format("%s-%s-base",var.project,var.systemenv)
     "Environment" = var.systemenv
     "TFGroup" = "base"
     "Configsrc" = "terraform"
     "Owner" = "bitbool"
     "Contact" = "panos@bitbool.net"
    }
  }
}



data "aws_acm_certificate" "app-us" {
  provider = aws.us-east-1

  for_each = { for k,v in local.certificates: k => v if lookup(v,"existing",false) && lookup(v,"cloudfront",false) }

  domain      = tobool(lookup(each.value,"aws_issued",false)) ? local.app_cert_cn[each.key] : each.value.path
  #types       = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "app" {
  for_each = { for k,v in local.certificates: k => v if lookup(v,"existing",false) }

  domain      = tobool(lookup(each.value,"aws_issued",false)) ? local.app_cert_cn[each.key] : each.value.path
  #types       = ["ISSUED"]
  most_recent = true
}


## THIS IS USED FOR CLOUDFRONT BECAUSE IT ONLY SEES CERTS IN us-east-1
resource "aws_acm_certificate" "app-us" {
  provider = aws.us-east-1

  for_each = { for k,v in local.certificates: k => v if !lookup(v,"existing",false) && lookup(v,"cloudfront",false) } 

  private_key               = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.key",var.certificates_path,each.value.path))
  certificate_body          = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.crt",var.certificates_path,each.value.path))
  certificate_chain         = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/chain-%s.pem",var.certificates_path,lookup(each.value,"chain",var.certificates_default_chain)))

  domain_name               = tobool(lookup(each.value,"aws_issued",false)) ? local.app_cert_cn[each.key] : null
  validation_method         = tobool(lookup(each.value,"aws_issued",false)) ? "DNS" : null 
  subject_alternative_names = tobool(lookup(each.value,"aws_issued",false)) ? try(local.app_cert_sans[each.key],null) : null 

  lifecycle {
    create_before_destroy = true
  }

  tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.key)}, local.tags_module_acm)

}


resource "aws_acm_certificate" "app" {
  for_each = { for k,v in local.certificates: k => v if !lookup(v,"existing",false) } 

  private_key               = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.key",var.certificates_path,each.value.path))
  certificate_body          = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.crt",var.certificates_path,each.value.path))
  certificate_chain         = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/chain-%s.pem",var.certificates_path,lookup(each.value,"chain",var.certificates_default_chain)))

  domain_name               = tobool(lookup(each.value,"aws_issued",false)) ? local.app_cert_cn[each.key] : null
  validation_method         = tobool(lookup(each.value,"aws_issued",false)) ? "DNS" : null 
  subject_alternative_names = tobool(lookup(each.value,"aws_issued",false)) ? try(local.app_cert_sans[each.key],null) : null 

  lifecycle {
    create_before_destroy = true
  }

  tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.key)}, local.tags_module_acm)

}

# resource "aws_route53_record" "app_cert_validation" {
#   for_each = { for v in local.app_cert_validations: v.key => v }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = each.value.zone_aws == data.aws_route53_zone.cluster.name ? data.aws_route53_zone.cluster.id : data.aws_route53_zone.app[each.value.zone_aws].zone_id
# }

locals {

  #certificates = merge({"platform" = { aws_issued = true, domains = [{ zone = data.aws_route53_zone.cluster.name, records = ["","*","*.test","*.staging"] }]} },var.app_certificates)
  certificates = var.app_certificates

  app_cert_info = {
    for certk,certv in local.certificates: certk => merge(flatten([
      for d in certv.domains: {
        for r in d.records: "${format("%s%s",(length(r)>0 ? "${r}.": ""),d.zone)}" => {
          cert   = certk
          zone_aws = d.zone
          zone_dns = length(r) == 0 ? d.zone :replace(format("%s%s",(length(r)>0 ? "${r}.": ""),d.zone),"/^[^.]*./","")
          record = r
          domain = format("%s%s",(length(r)>0 ? "${r}.": ""),d.zone)
          is_san = (index(certv.domains,d) == 0 && index(d.records,r) == 0)? false : true
          is_wildcard = (length(regexall("\\*",r)) > 0)
          existing = certv.existing
        }
      }
    ])...) if tobool(lookup(certv,"aws_issued",false))
  }

  app_cert_cn = {
    for certk,certv in local.app_cert_info: certk => [for k,v in certv: v.domain if v.is_san == false ][0]
  }

  app_cert_sans = {
    for certk,certv in local.app_cert_info: certk => [for k,v in certv: v.domain if v.is_san == true ]
  }

  app_cert_san_is_covered_by_wildcard = {
    for certk,certv in local.app_cert_info: certk => {
      for sanK,sanV in certv : sanK => length([ 
          # get other SAN that:
          # - are wildcard
          # - are not me
          # - have either same dns zone with me, or I am the "root" record of the wildcard domain == I am domain.zone.gr and there *.domain.zone.gr
          for otherSanK,otherSanV in certv : otherSanK if ( ((otherSanV.zone_dns == sanV.domain) || (otherSanV.zone_dns == sanV.zone_dns)  ) && (otherSanK != sanK) && (otherSanV.is_wildcard))
        ] 
      )>0 if sanV.is_wildcard == false #check only non wildcard domains, wildcard domains are always validated
    }
  }  

  app_cert_validations = flatten([
    for certk,certv in local.app_cert_info: [
      for dvo in aws_acm_certificate.app[certk].domain_validation_options : {
          key    = "${certk}-${dvo.domain_name}"
          cert   = certk
          domain = dvo.domain_name
          name   = dvo.resource_record_name
          record = dvo.resource_record_value
          type   = dvo.resource_record_type
          zone_aws = certv[dvo.domain_name].zone_aws
      } if ( 
            certv[dvo.domain_name].is_wildcard == true 
            || try(local.app_cert_san_is_covered_by_wildcard[certk][dvo.domain_name],false) == false
          ) 
          && contains(lookup(local.certificates[certk],"exlude_from_validation",[]),dvo.domain_name) == false
    ] if local.certificates[certk].existing == false
  ])
}

output "app_cert_info" {
  value = local.app_cert_info
}

output "app_cert_cn" {
  value = local.app_cert_cn
}

output "app_cert_san_is_covered_by_wildcard" {
  value = local.app_cert_san_is_covered_by_wildcard
}

# output "app_cert_validations" {
#   value = local.app_cert_validations
# }




### example of static

# resource "aws_acm_certificate" "main" {
#   domain_name = data.aws_route53_zone.cluster.name
#   validation_method = "DNS"

#   subject_alternative_names = [ format("*.%s",data.aws_route53_zone.cluster.name) ]

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,var.dns_zone_internal)}, local.tags_module_acm)

# }

# resource "aws_route53_record" "main_cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#    # Skips the domain if it doesn't contain a wildcard
#     if length(regexall("\\*\\..+", dvo.domain_name)) > 0
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.cluster.zone_id
# }

# resource "aws_acm_certificate_validation" "main" {
#   certificate_arn         = aws_acm_certificate.main.arn
#   validation_record_fqdns = [for record in aws_route53_record.main_cert_validation : record.fqdn]
# }



###### OLD TO GO #############
# resource "aws_acm_certificate" "app" {
#   for_each = local.certificates 

#   private_key = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.key",var.certificates_path,each.value.path))
#   certificate_body = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/%s.key",var.certificates_path,each.value.path))
#   certificate_chain = tobool(lookup(each.value,"aws_issued",false)) ? null : file(format("%s/chain-%s.pem",var.certificates_path,lookup(each.value,"chain",local.certificates_default_chain)))

#   domain_name = tobool(lookup(each.value,"aws_issued",false)) ?  format("%s%s",(length(each.value.domain)>0 ? "${each.value.domain}." : ""),each.value.zone) : null
#   validation_method = tobool(lookup(each.value,"aws_issued",false)) ? "DNS" : null 
#   subject_alternative_names = try(local.app_cert_sans4cert[each.key],null) #length(local.app_cert_sans[each.key]) > 0 ? local.app_cert_sans[each.key] : null  #tobool(lookup(each.value,"aws_issued",false)) ? lookup(app_cert_sans,certk,null) : null 

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.key)}, local.tags_module_acm)

# }

# locals {


#   app_cert_sans4cert = {
#     for certk,certv in local.certificates: certk => flatten([
#       for san in lookup(certv,"san",[]) : [
#         for d in san.domains: format("%s%s",(length(d)>0 ? "${d}.": ""),lookup(san,"zone",certv.zone))
#       ]
#     ]) if tobool(lookup(certv,"aws_issued",false))
#   }

#   app_cert_domain_info_base = {
#     for certk,certv in local.certificates: certk => flatten(concat(
#       [
#         {
#           for san in lookup(certv,"san",[]) : "${lookup(san,"zone",certv.zone)}" => {
#             for d in san.domains: "${format("%s%s",(length(d)>0 ? "${d}.": ""),lookup(san,"zone",certv.zone))}" => { 
#               san  = format("%s%s",(length(d)>0 ? "${d}.": ""),lookup(san,"zone",certv.zone)),
#               zone = lookup(san,"zone",certv.zone)
#               is_san = true
#               is_wildcard = (length(regexall("\\*",d)) > 0)
#             }

#           }
#         }
#       ],
#       [ 
#         {
#           "${certv.zone}" = { 
#               "${format("%s%s",(length(certv.domain)>0 ? "${certv.domain}." : ""),certv.zone)}" = {
#                   san  = format("%s%s",(length(certv.domain)>0 ? "${certv.domain}." : ""),certv.zone)
#                   zone = certv.zone
#                   is_san = false
#                   is_wildcard = (length(regexall("\\*",certv.domain)) > 0)
#                 }
#           }
#         }
#       ]
#     )) 
#   }

#   app_cert_domain_info = {
#     for certk,certv in local.certificates: certk => {
#       for domain in 
#     }
#   }


#   # app_cert_domain_info = {
#   #   for certk,certv in local.certificates: certk => flatten(concat(
#   #     [
#   #       for san in lookup(certv,"san",[]) : [
#   #         for d in san.domains: { 
#   #           san  = format("%s%s",(length(d)>0 ? "${d}.": ""),lookup(san,"zone",certv.zone)),
#   #           zone = lookup(san,"zone",certv.zone)
#   #           is_san = true
#   #           is_wildcard = (length(regexall("\\*",d)) > 0)
#   #         }
#   #       ]
#   #     ],
#   #     [ 
#   #       { 
#   #         san  = format("%s%s",(length(certv.domain)>0 ? "${certv.domain}." : ""),certv.zone)
#   #         zone = certv.zone
#   #         is_san = false
#   #         is_wildcard = (length(regexall("\\*",certv.domain)) > 0)          
#   #       }
#   #     ]
#   #   )) 
#   # }

#   app_cert_validations = flatten([
#     for certk,certv in local.certificates: [
#       for dvo in aws_acm_certificate.app[certk].domain_validation_options : {
#           key    = "${certk}-${dvo.domain_name}"
#           cert   = certk
#           domain = dvo.domain_name
#           name   = dvo.resource_record_name
#           record = dvo.resource_record_value
#           type   = dvo.resource_record_type
#       } 
#     ] if tobool(lookup(certv,"aws_issued",false)) #&& alltrue([for dvo in aws_acm_certificate.app[certk].domain_validation_options: length(regexall("\\*\\..+", dvo.domain_name)) < 0 ])
#   ])

#   # app_cert_simpleCerts2validate = { 
#   #   for certk,certv in local.certificates: certk => certv if tobool(lookup(certv,"aws_issued",false)) && for 
#   # }

#   # app_cert_validations2 = flatten([
#   #   for certk,certv in local.certificates: [
#   #     for dvo in aws_acm_certificate.app[certk].domain_validation_options : {
#   #         key    = "${certk}-${dvo.domain_name}"
#   #         cert   = certk
#   #         domain = dvo.domain_name
#   #         name   = dvo.resource_record_name
#   #         record = dvo.resource_record_value
#   #         type   = dvo.resource_record_type
#   #     } 
#   #   ] if tobool(lookup(certv,"aws_issued",false)) #&& alltrue([for dvo in aws_acm_certificate.app[certk].domain_validation_options: length(regexall("\\*\\..+", dvo.domain_name)) < 0 ])
#   # ])

#   # app_cert_validations = flatten([
#   #   for certk,certv in local.certificates: [
#   #     for dvo in aws_acm_certificate.app[certk].domain_validation_options : {
#   #         key    = "${certk}-${dvo.domain_name}"
#   #         cert   = certk
#   #         domain = dvo.domain_name
#   #         name   = dvo.resource_record_name
#   #         record = dvo.resource_record_value
#   #         type   = dvo.resource_record_type
#   #     } 
#   #   ] if tobool(lookup(certv,"aws_issued",false)) && alltrue([for san in lookup(certv,"san",[]) : length(regexall("\\*\\..+", san)) == 0 ])
#   # ])



# }

# output "app_cert_domain_info" {
#   value = local.app_cert_domain_info
# }
# resource "aws_route53_record" "app_cert_validation" {
#   for_each = { for v in local.app_cert_validations: v.key => v }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.cluster.zone_id
# }
