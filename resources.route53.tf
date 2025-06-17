data "aws_route53_zone" "cluster" {
  name         = var.dns_zone_internal
}

data "aws_route53_zone" "app" {
  for_each = { for zone in var.route53_app_zones: zone => zone }

  name         = each.key
}

resource "aws_route53_record" "app_internal_balancer" {
  for_each = { for u in local.internal_urls_all: u.key => u... if lookup(var.apps[u.app],"route53_urls_internal_balancer",true) }  # ... is ellipsis operator to merge under the same key

  zone_id = data.aws_route53_zone.cluster.zone_id
  name    = format("%s.%s",each.key,data.aws_route53_zone.cluster.name)
  type    = "CNAME"
  ttl     = 300
  records = [each.value[0].cname]
}

resource "aws_route53_record" "main_urls_balancer" {
  for_each = { for u in local.main_urls_all: u.key => u... if lookup(var.apps[u.app],"route53_urls_balancer",true) }  # ... is ellipsis operator to merge under the same key

  zone_id = data.aws_route53_zone.app[each.value[0].zone].zone_id
  name    = each.key
  type    = "A"

  alias {
    name                   = aws_lb.app[each.value[0].balancer].dns_name
    zone_id                = aws_lb.app[each.value[0].balancer].zone_id
    evaluate_target_health = true
  }
}

# resource "aws_route53_record" "app_internal_cloudfront" {
#   for_each = { for u in local.internal_urls_all: u.key => u... if lookup(var.apps[u.app],"route53_urls_internal_cloudfront",false)!=false }  # ... is ellipsis operator to merge under the same key

#   zone_id = data.aws_route53_zone.cluster.zone_id
#   name    = format("%s.%s",each.key,data.aws_route53_zone.cluster.name)
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.app[var.apps[each.value[0].app]["route53_urls_internal_cloudfront"]].domain_name
#     zone_id                = aws_cloudfront_distribution.app[var.apps[each.value[0].app]["route53_urls_internal_cloudfront"]].hosted_zone_id
#     evaluate_target_health = false
#   }  
# }

# resource "aws_route53_record" "main_urls_cloudfront" {
#   for_each = { for u in local.main_urls_all: u.key => u... if lookup(var.apps[u.app],"route53_urls_cloudfront",false)!=false }  # ... is ellipsis operator to merge under the same key

#   zone_id = data.aws_route53_zone.cluster.zone_id
#   name    = each.key
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.app[var.apps[each.value[0].app]["route53_urls_cloudfront"]].domain_name
#     zone_id                = aws_cloudfront_distribution.app[var.apps[each.value[0].app]["route53_urls_cloudfront"]].hosted_zone_id
#     evaluate_target_health = false
#   }  
# }




# output "test" {
#   value = { for u in local.internal_urls_all: u.key => u... }
# }