# resource "aws_wafv2_web_acl_association" "example" {
#   for_each = { for k,v in var.app_lbs: k=>v if lookup(v,"waf",false)!=false }

#   resource_arn = aws_lb.app[each.key].arn
#   web_acl_arn  = data.terraform_remote_state.waf.outputs.waf_arns[each.value.waf]
# }

resource "aws_wafv2_web_acl_association" "waf" {
  for_each = { for k,v in var.app_lbs : k=>v if lookup(v,"waf",null) != null }

  resource_arn = aws_lb.app[each.key].arn
  web_acl_arn  = try(var.waf_arns[each.value.waf],null)
}