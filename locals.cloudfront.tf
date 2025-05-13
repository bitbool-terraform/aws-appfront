locals {

  cloudfront_behaviors = {
    default = {
        "jpg" = {
          "path" = "/*.jpg"
          "cache_policy" = "staticWQueryString"
        }
        "png" = {
          "path" = "/*.png"
          "cache_policy" = "staticWQueryString"
        }
        "ico" = {
          "path" = "/*.ico"
          "cache_policy" = "staticWQueryString"
        }
        "css" = {
          "path" = "/*.css"
          "cache_policy" = "staticWQueryString"
        }
        "js" = {
          "path" = "/*.js"
          "cache_policy" = "staticWQueryString"
        }
      }
    fast = {
        "jpg" = {
          "path" = "/*.jpg"
          "cache_policy" = "fast"
        }
        "png" = {
          "path" = "/*.png"
          "cache_policy" = "fast"
        }
        "ico" = {
          "path" = "/*.ico"
          "cache_policy" = "fast"
        }
        "css" = {
          "path" = "/*.css"
          "cache_policy" = "fast"
        }
        "js" = {
          "path" = "/*.js"
          "cache_policy" = "fast"
        }
      }      
  }

}