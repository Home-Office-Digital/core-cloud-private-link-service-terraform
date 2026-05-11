output "endpoint_service_names" {
  description = "Service names tenants use to create Interface VPC Endpoints"

  value = {
    for svc_key, svc in aws_vpc_endpoint_service.privatelink_service :
    svc_key => svc.service_name
  }
}

output "nlb_arns" {
  value = {
    for k, v in aws_lb.nlb :
    k => v.arn
  }
}

output "listener_arns" {
  value = {
    for k, v in aws_lb_listener.listener :
    k => v.arn
  }
}

output "target_group_arns" {
  value = {
    for k, v in aws_lb_target_group.tg :
    k => v.arn
  }
}