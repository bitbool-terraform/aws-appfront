locals {

  cloudfront_policies_wellknown = {
    "UserAgentRefererHeaders" = "acba4595-bd28-49b8-b9fe-13317c0390fa"
    "AllViewerAndCloudFrontHeaders-2022-06" = "33f36d7e-f396-46d9-90e0-52428a34d9dc"
    "CachingDisabled" = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    "CachingOptimized" = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  cloudfront_policies_available_arns_origin_request = merge(
    {for key,value in local.cloudfront_requests_policies[terraform.workspace]: key => aws_cloudfront_origin_request_policy.request[key].id},
    {
      "UserAgentRefererHeaders" = local.cloudfront_policies_wellknown["UserAgentRefererHeaders"]
      "AllViewerAndCloudFrontHeaders-2022-06" = local.cloudfront_policies_wellknown["AllViewerAndCloudFrontHeaders-2022-06"]
    }
  )
  
  cloudfront_policies_available_arns_cache_policies = merge(
    {for key,value in local.cloudfront_cache_policies[terraform.workspace]: key => aws_cloudfront_cache_policy.caching[key].id},
    {
      "CachingDisabled" = local.cloudfront_policies_wellknown["CachingDisabled"],
      "CachingOptimized" = local.cloudfront_policies_wellknown["CachingOptimized"]
    }
  )  
}



locals {
  cloudfront_cache_policies = {
    "production" = local.cloudfront_cache_policies_common
    "empty" = local.cloudfront_cache_policies_empty
  }

  cloudfront_cache_policies_empty = {}

  cloudfront_cache_policies_common  = {
    "fast" = {
        "name" = "fast"
        "default_ttl" = 600
        "max_ttl" = 900
        #"header_behavior" = "whitelist"
        #"headers" = ["CloudFront-Viewer-Country"]
    }
    "fastWQueryString" = {
        "name" = "fastWQueryString"
        "default_ttl" = 600
        "max_ttl" = 900
        # "header_behavior" = "whitelist"
        # "headers" = ["Host"]
        "query_string_behavior"="all"
        "cookie_behavior" = "all"        
    }    
    # "static" = {
    #     "name" = "static"
    #     "default_ttl" = 3600
    #     "max_ttl" = 4*3600
    # }
    "staticWQueryString" = {
        "name" = "staticWQueryString"
        "default_ttl" = 3600
        "max_ttl" = 4*3600
        "header_behavior" = "whitelist"
        "headers" = ["Host"]
        "query_string_behavior"="all"
    }    
  }
}


resource "aws_cloudfront_cache_policy" "caching" {
  for_each =  local.cloudfront_cache_policies[terraform.workspace]

  name    = format("%s-%s-cache-%s",var.project,var.systemenv,each.value.name)
  comment = format("%s-%s-cache-%s",var.project,var.systemenv,each.value.name)

  default_ttl = each.value.default_ttl
  max_ttl     = each.value.max_ttl
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = lookup(each.value,"cookie_behavior","none")
    }
    headers_config {
      header_behavior = lookup(each.value,"header_behavior","none")
      dynamic "headers" {
        for_each = { for k, v in { "${each.key}" : each.value } :  k => v if lookup(v,"headers",false) != false } #"
        content {
          items = each.value.headers
        }
      }      
    }
    query_strings_config {
      query_string_behavior = lookup(each.value,"query_string_behavior","none")
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip  = true
  }
}

locals {
  cloudfront_requests_policies = {
    "production" = local.cloudfront_requests_policies_common
    "empty" = local.cloudfront_requests_policies_empty
  }

  cloudfront_requests_policies_empty  = {}

  cloudfront_requests_policies_common  = {
    "main" = {
        "name" = "main"
        "headers" = ["Host","x-bot","Referer","X-ApiToken","X-MyUserAgent","x-original-host","Origin","CloudFront-Viewer-Country"]
        "cookie_behavior" = "all"
    }
    # "noHost" = {
    #     "name" = "noHost"
    #     "headers" = ["x-bot","Referer","X-ApiToken","X-MyUserAgent","x-original-host","Origin","CloudFront-Viewer-Country"]
    #     "cookie_behavior" = "all"
    # }    
    # "blog" = {
    #     "name" = "blog"
    #     "headers" = ["Referer","x-original-host","Origin","CloudFront-Viewer-Country"]
    #     "cookie_behavior" = "all"
    # }        
    # "cdn" = {
    #     "name" = "cdn"
    #     "headers" = ["x-bot","Referer","X-ApiToken","X-MyUserAgent","x-original-host"]
    #     "query_string_behavior" = "none"
    # }    
  }
}


resource "aws_cloudfront_origin_request_policy" "request" {
  for_each =  local.cloudfront_requests_policies[terraform.workspace]
  
  name    = format("%s-%s-request-%s",var.project,var.systemenv,each.value.name)
  comment = format("%s-%s-request-%s",var.project,var.systemenv,each.value.name)
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = each.value.headers
    }
  }
  cookies_config {
    cookie_behavior = lookup(each.value,"cookie_behavior","none")
  }
  query_strings_config {
    query_string_behavior = lookup(each.value,"query_string_behavior","all")
  }  
}
