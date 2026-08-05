############################
# S3 bucket for NLB access logs
############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  default_nlb_access_logs_bucket_name = format(
    "%s-nlb-access-logs-%s-%s",
    var.name_prefix,
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.region
  )

  nlb_access_logs_bucket_name = coalesce(var.existing_nlb_access_logs_bucket_name, local.default_nlb_access_logs_bucket_name)
}

# One log bucket shared by all NLBs in this module
resource "aws_s3_bucket" "nlb_access_logs" {
  #checkov:skip=CKV2_AWS_62:NLB access logs bucket is intentionally notification-free in this module.
  #checkov:skip=CKV_AWS_145:AES256 encryption is sufficient for this log sink; KMS is not required here.
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally not enabled for transient access logs.
  #checkov:skip=CKV_AWS_21:Bucket versioning is intentionally disabled for write-once access logs.
  #checkov:skip=CKV_AWS_18:Bucket access logging is intentionally not enabled to avoid recursive log writes.
  count  = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket = local.nlb_access_logs_bucket_name

  tags = var.tags
}


# Keep ownership so logs land correctly
resource "aws_s3_bucket_ownership_controls" "nlb_access_logs" {
  #checkov:skip=CKV2_AWS_65:BucketOwnerPreferred is required for ELB/NLB access log delivery ACL behavior.
  count  = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.nlb_access_logs[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "nlb_access_logs" {
  count                   = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket                  = aws_s3_bucket.nlb_access_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# (Optional) Encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "nlb_access_logs" {
  count  = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.nlb_access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle to control cost
resource "aws_s3_bucket_lifecycle_configuration" "nlb_access_logs" {
  count  = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.nlb_access_logs[0].id

  rule {
    id     = "expire-nlb-logs"
    status = "Enabled"

    expiration {
      days = var.nlb_access_logs_retention_days
    }
  }
}

# Allow Elastic Load Balancing log delivery to write into this bucket
# Notes:
# - This uses the modern log delivery service principals.
# - The ACL condition is important for ownership expectations.
resource "aws_s3_bucket_policy" "nlb_access_logs" {
  count  = var.existing_nlb_access_logs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.nlb_access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "HTTPSOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.nlb_access_logs[0].arn,
          "${aws_s3_bucket.nlb_access_logs[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },

      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.nlb_access_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.nlb_access_logs[0].arn
      }
    ]
  })
}

############################
# Network Load Balancer with access logging enabled
############################

resource "aws_lb" "nlb" {
  #checkov:skip=CKV_AWS_150:Deletion protection is intentionally disabled for Terraform-managed ephemeral environments.
  for_each = var.pl_services

  name                             = each.value.name
  load_balancer_type               = "network"
  internal                         = true
  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = local.nlb_access_logs_bucket_name
    prefix  = "nlb/${each.value.name}"
    enabled = true
  }

  tags = var.tags

  depends_on = [
    aws_s3_bucket_policy.nlb_access_logs,
    aws_s3_bucket_ownership_controls.nlb_access_logs
  ]
}

###################
# Target Group
###################

resource "aws_lb_target_group" "tg" {
  for_each = var.pl_services

  name        = "${each.value.name}-tg"
  vpc_id      = var.vpc_id
  port        = each.value.listener_port
  protocol    = each.value.protocol
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }

  tags = var.tags
}

###################
# Listener
###################

resource "aws_lb_listener" "listener" {
  #checkov:skip=CKV_AWS_2:This module provisions NLB listeners (TCP/TLS), not ALB HTTPS listeners.
  #checkov:skip=CKV_AWS_103:Listener protocol and TLS policy are service-driven and may be TCP by design.
  for_each = var.pl_services

  load_balancer_arn = aws_lb.nlb[each.key].arn
  port              = each.value.listener_port
  protocol          = each.value.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[each.key].arn
  }

  tags = var.tags
}

###################
# Target Group Attachments (3 IPs)
###################

resource "aws_lb_target_group_attachment" "target_0" {
  for_each = var.pl_services

  target_group_arn  = aws_lb_target_group.tg[each.key].arn
  target_id         = each.value.service_target_ips[0]
  port              = each.value.listener_port
  availability_zone = "all"
}

resource "aws_lb_target_group_attachment" "target_1" {
  for_each = var.pl_services

  target_group_arn  = aws_lb_target_group.tg[each.key].arn
  target_id         = each.value.service_target_ips[1]
  port              = each.value.listener_port
  availability_zone = "all"
}

resource "aws_lb_target_group_attachment" "target_2" {
  for_each = var.pl_services

  target_group_arn  = aws_lb_target_group.tg[each.key].arn
  target_id         = each.value.service_target_ips[2]
  port              = each.value.listener_port
  availability_zone = "all"
}

###################
# VPC Endpoint Service (PrivateLink)
###################

resource "aws_vpc_endpoint_service" "privatelink_service" {
  #checkov:skip=CKV_AWS_123:acceptance_required is configurable per service and may be false for trusted principals.
  for_each = var.pl_services

  acceptance_required        = each.value.acceptance_required
  network_load_balancer_arns = [aws_lb.nlb[each.key].arn]
  allowed_principals         = each.value.allowed_principals
  supported_regions          = try(each.value.supported_regions, var.supported_regions, null)

  tags = merge(
    var.tags,
    {
      Name = each.value.name
    }
  )
}
