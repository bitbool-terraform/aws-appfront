# example
# cloudfronts = {
#   # test = {
#   #   name = "test"
#   #   certificate = "transportV"
#   #   balancer = "main"
#   #   urls = ["submit.metaforikoisodinamo.gr"]
#   # }
# }

resource "aws_cloudfront_distribution" "app" {
  for_each = var.cloudfronts

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = lookup(var.app_certificates[each.value.certificate],"existing",false)? data.aws_acm_certificate.app-us[each.value.certificate].arn : aws_acm_certificate.app-us[each.value.certificate].arn 
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"
  wait_for_deployment = false
 
  origin {
    domain_name = aws_lb.app[each.value.balancer].dns_name  
    origin_id   = "app"
    #origin_path = "/"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "match-viewer"#"http-only"  
      origin_ssl_protocols = ["TLSv1.2"]
    }

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = each.value.name
  #default_root_object = "index.aspx"

  # logging_config {
  #   include_cookies = false
  #   bucket          = aws_s3_bucket.cloudfrontlogs[each.key].bucket_domain_name
  #   prefix          = "cloufront_resources"
  # }

  aliases = each.value.urls

  default_cache_behavior {
    compress = true
    allowed_methods  = lookup(each.value,"allowed_methods",["GET", "HEAD", "POST", "PUT", "OPTIONS", "DELETE", "PATCH"])
    cached_methods   = lookup(each.value,"cached_methods",["GET", "HEAD", "OPTIONS"])
    target_origin_id = "app"

    origin_request_policy_id = local.cloudfront_policies_available_arns_origin_request[lookup(each.value,"origin_request_policy","UserAgentRefererHeaders")]
    cache_policy_id          = local.cloudfront_policies_available_arns_cache_policies[lookup(each.value,"cache_policy","CachingDisabled")]

    viewer_protocol_policy = "redirect-to-https" #"allow-all"
    min_ttl                = 0
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.cloudfront_behaviors[each.value.behaviors]

    content {
      path_pattern     = ordered_cache_behavior.value.path
      compress = true
      allowed_methods  = lookup(ordered_cache_behavior.value,"allowed_methods",["GET", "HEAD", "POST", "PUT", "OPTIONS", "DELETE", "PATCH"])
      cached_methods   = lookup(ordered_cache_behavior.value,"cached_methods",["GET", "HEAD", "OPTIONS"])
      target_origin_id = lookup(ordered_cache_behavior.value,"origin","app")

      origin_request_policy_id = local.cloudfront_policies_available_arns_origin_request[lookup(ordered_cache_behavior.value,"origin_request_policy",lookup(each.value,"origin_request_policy","UserAgentRefererHeaders"))]
      cache_policy_id          = local.cloudfront_policies_available_arns_cache_policies[lookup(ordered_cache_behavior.value,"cache_policy","CachingDisabled")]

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
    }
  }    


}
