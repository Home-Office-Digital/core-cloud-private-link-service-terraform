mock_provider "aws" {}

run "plan_valid_endpoint_service" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      orders = {
        name               = "example-orders-pls"
        service_target_ips = ["192.0.2.10", "192.0.2.11", "192.0.2.12"]
        listener_port      = 443
        protocol           = "TCP"
      }
    }
  }

  assert {
    condition     = length(output.endpoint_service_names) == 1
    error_message = "Expected one endpoint service name in outputs."
  }

  assert {
    condition     = can(output.endpoint_service_names["orders"])
    error_message = "Expected output key 'orders' to be present."
  }
}

run "plan_two_services_with_existing_log_bucket" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    existing_nlb_access_logs_bucket_name = "example-shared-log-bucket"

    pl_services = {
      orders = {
        name               = "example-orders-pls"
        service_target_ips = ["192.0.2.30", "192.0.2.31", "192.0.2.32"]
      }
      billing = {
        name               = "example-billing-pls"
        service_target_ips = ["192.0.2.40", "192.0.2.41", "192.0.2.42"]
        listener_port      = 8443
        protocol           = "TCP"
      }
    }
  }

  assert {
    condition     = length(output.endpoint_service_names) == 2
    error_message = "Expected output values for two endpoint services."
  }

  assert {
    condition     = can(output.endpoint_service_names["orders"]) && can(output.endpoint_service_names["billing"])
    error_message = "Expected both service keys in endpoint_service_names output."
  }
}

run "reject_invalid_target_ip_count" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      invalid = {
        name               = "example-invalid-pls"
        service_target_ips = ["192.0.2.20", "192.0.2.21"]
      }
    }
  }

  expect_failures = [var.pl_services]
}

run "reject_more_than_three_target_ips" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      invalid = {
        name               = "example-invalid-pls"
        service_target_ips = ["192.0.2.50", "192.0.2.51", "192.0.2.52", "192.0.2.53"]
      }
    }
  }

  expect_failures = [var.pl_services]
}

run "reject_empty_target_ips" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      invalid = {
        name               = "example-empty-targets-pls"
        service_target_ips = []
      }
    }
  }

  expect_failures = [var.pl_services]
}