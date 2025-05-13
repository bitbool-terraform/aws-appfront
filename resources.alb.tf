resource "aws_lb" "app" {
  for_each = var.app_lbs

  load_balancer_type = "application"
  internal           = false

  name               = format("%s-%s-%s",var.project,var.systemenv,each.value.name)
  
  security_groups    = [aws_security_group.app_lb[each.key].id,aws_security_group.all_lbs.id,]
  subnets            = local.lb_subnets[each.key]

  enable_deletion_protection = false

  desync_mitigation_mode = "defensive"
  drop_invalid_header_fields = false
  enable_http2 = true
  idle_timeout = 600
  preserve_host_header = true

  ip_address_type = "ipv4" #"dualstack"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs[each.key].bucket
    prefix  = "lblogs"
    enabled = true
  }

  # dynamic "subnet_mapping" {
  #   for_each = { for k,v in local.lb_eips: k => v if v.balancer == each.key }
  #   content {
  #     subnet_id = subnet_mapping.value.subnet_id
  #     allocation_id = aws_eip.lb-eip[subnet_mapping.value.eip_key].id
  #   }
  # }

  tags = merge( {Name = format("%s-%s-%s",var.project,var.systemenv,each.value.name)}, local.tags_module_alb)
  
  lifecycle {
    ignore_changes = [tags,security_groups]
  }

}

resource "aws_route53_record" "app-lb" {
  for_each = var.app_lbs

  zone_id = data.aws_route53_zone.cluster.zone_id
  name    = format("lb-%s-%s-%s.%s",var.project,var.systemenv,each.value.name,data.aws_route53_zone.cluster.name)
  type    = "A"

  alias {
    name                   = aws_lb.app[each.key].dns_name
    zone_id                = aws_lb.app[each.key].zone_id
    evaluate_target_health = false
  }
}

locals {
  s3_bucket_name_alb_logs = { for k,v in var.app_lbs: k => format("%s-%s-balancerlogs-%s",var.project,var.systemenv,v.name) }
}

data "aws_elb_service_account" "default" {}

data "aws_iam_policy_document" "albaccess" {
  for_each = var.app_lbs

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.default.arn]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${local.s3_bucket_name_alb_logs[each.key]}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  for_each = var.app_lbs

  bucket = aws_s3_bucket.alb_logs[each.key].id
  policy = data.aws_iam_policy_document.albaccess[each.key].json
}

resource "aws_s3_bucket" "alb_logs" {
  for_each = var.app_lbs

  bucket = local.s3_bucket_name_alb_logs[each.key]

  tags = merge( {Name = local.s3_bucket_name_alb_logs[each.key]}, local.tags_module_s3 )

}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  for_each = var.app_lbs

  bucket = aws_s3_bucket.alb_logs[each.key].id

  rule {
    id      = format("%s-root",local.s3_bucket_name_alb_logs[each.key])

    filter {
      and {
        prefix = "/"
        tags = {
          rule      = format("%s-root",local.s3_bucket_name_alb_logs[each.key])
          autoclean = "true"
        }
      }
    }

    noncurrent_version_expiration {
      noncurrent_days = 1095
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    status = "Enabled"

  }
}

# resource "aws_s3_bucket_acl" "alb_logs" {
#   for_each = var.app_lbs

#   bucket = aws_s3_bucket.alb_logs[each.key].id
#   acl    = "private"
# }

resource "aws_s3_bucket_versioning" "alb_logs" {
  for_each = var.app_lbs

  bucket = aws_s3_bucket.alb_logs[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_security_group" "all_lbs" {
  name        = format("%s-%s-balancers-all",var.project,var.systemenv)
  description = format("%s-%s-balancers-all",var.project,var.systemenv)
  vpc_id      = local.vpc_id

  tags = merge( {Name = format("%s-%s-balancers-all",var.project,var.systemenv)}, local.tags_module_sgs  )
}

resource "aws_security_group" "app_lb" {
  for_each = var.app_lbs

  name        = format("%s-%s-balancer-%s",var.project,var.systemenv,each.key)
  description = format("%s-%s-balancer-%s",var.project,var.systemenv,each.key)
  vpc_id      = local.vpc_id

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "allow all outgoing"
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "allow all incoming"
  }
  tags = merge( {Name = format("%s-%s-balancer-%s",var.project,var.systemenv,each.key)}, local.tags_module_sgs  )
}
