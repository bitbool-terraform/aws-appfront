locals {
  s3_bucket_name_accelarator_logs = { for k,v in var.accelerators: k => format("%s-%s-acceleratorlogs-%s",var.project,var.systemenv,v.name) }
}

output "accelerator_ips" {
  value = [ for a in aws_globalaccelerator_accelerator.app: a.ip_sets]
}
resource "aws_globalaccelerator_accelerator" "app" {
  for_each = var.accelerators 

  name            = format("%s-%s-%s",var.project,var.systemenv,each.value.name)
  ip_address_type = "DUAL_STACK"
  enabled         = lookup(each.value,"enabled",true)

  attributes {
    flow_logs_enabled   = true
    flow_logs_s3_bucket = aws_s3_bucket.accelator_logs[each.key].bucket
    flow_logs_s3_prefix = format("flow-logs-%s/",each.key)
  }

    tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.value.name)}, local.tags_module_accelerator)
}

resource "aws_globalaccelerator_listener" "http" {
  for_each = var.accelerators 

  accelerator_arn = aws_globalaccelerator_accelerator.app[each.key].id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_listener" "https" {
  for_each = var.accelerators 

  accelerator_arn = aws_globalaccelerator_accelerator.app[each.key].id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "http" {
  for_each = var.accelerators 
 
  listener_arn = aws_globalaccelerator_listener.http[each.key].id

  endpoint_group_region         = var.aws_region
  health_check_interval_seconds = try(each.value.endpoint_group.health_check_interval_seconds, null)
  health_check_path             = try(each.value.endpoint_group.health_check_path, null)
  health_check_port             = try(each.value.endpoint_group.health_check_port, null)
  health_check_protocol         = try(each.value.endpoint_group.health_check_protocol, null)
  threshold_count               = try(each.value.endpoint_group.threshold_count, null)
  traffic_dial_percentage       = try(each.value.endpoint_group.traffic_dial_percentage, null)

  endpoint_configuration {
    client_ip_preservation_enabled = try(each.value.endpoint_group.client_ip_preservation_enabled, true)
    endpoint_id                    = aws_lb.app[each.value.lb].arn
    weight                         = 128
  }
}

resource "aws_globalaccelerator_endpoint_group" "https" {
  for_each = var.accelerators 
 
  listener_arn = aws_globalaccelerator_listener.https[each.key].id

  endpoint_group_region         = var.aws_region
  health_check_interval_seconds = try(each.value.endpoint_group.health_check_interval_seconds, null)
  health_check_path             = try(each.value.endpoint_group.health_check_path, null)
  health_check_port             = try(each.value.endpoint_group.health_check_port, null)
  health_check_protocol         = try(each.value.endpoint_group.health_check_protocol, null)
  threshold_count               = try(each.value.endpoint_group.threshold_count, null)
  traffic_dial_percentage       = try(each.value.endpoint_group.traffic_dial_percentage, null)

  endpoint_configuration {
    client_ip_preservation_enabled = try(each.value.endpoint_group.client_ip_preservation_enabled, true)
    endpoint_id                    = aws_lb.app[each.value.lb].arn
    weight                         = 128
  }
}

resource "aws_s3_bucket" "accelator_logs" {
  for_each = var.accelerators

  bucket = local.s3_bucket_name_accelarator_logs[each.key]

  tags = merge( {Name = local.s3_bucket_name_accelarator_logs[each.key]}, local.tags_module_s3 )

}

resource "aws_s3_bucket_policy" "accelator_logs" {
  for_each = var.accelerators

  bucket = aws_s3_bucket.accelator_logs[each.key].id
  policy = data.aws_iam_policy_document.lb_log_delivery[each.key].json
}



# AWS Load Balancer access log delivery policy
data "aws_iam_policy_document" "elb_log_delivery" {
  for_each = var.accelerators

  statement {
    sid = ""

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.default.arn]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${local.s3_bucket_name_accelarator_logs[each.key]}/*",
    ]
  }
}

# ALB/NLB

data "aws_iam_policy_document" "lb_log_delivery" {
  for_each = var.accelerators

  statement {
    sid = "AWSLogDeliveryWrite"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${local.s3_bucket_name_accelarator_logs[each.key]}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid = "AWSLogDeliveryAclCheck"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      "arn:aws:s3:::${local.s3_bucket_name_accelarator_logs[each.key]}",
    ]

  }
}
