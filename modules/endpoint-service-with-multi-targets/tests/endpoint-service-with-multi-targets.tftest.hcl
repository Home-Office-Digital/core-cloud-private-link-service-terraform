mock_provider "aws" {}

run "plan_valid_endpoint_service_with_multiple_listeners" {
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
        service_target_ips = ["198.51.100.10", "198.51.100.11", "198.51.100.12"]
        listeners = {
          https = {
            listener_port = 443
            protocol      = "TCP"
          }
          grpc = {
            listener_port = 8443
            target_port   = 50051
            protocol      = "TCP"
          }
        }
      }
    }
  }

  assert {
    condition     = length(output.endpoint_service_names) == 1
    error_message = "Expected one endpoint service name in outputs."
  }

  assert {
    condition     = length(output.listener_arns) == 2
    error_message = "Expected one listener per configured listener block."
  }

  assert {
    condition     = can(output.target_group_arns["orders-https"]) && can(output.target_group_arns["orders-grpc"])
    error_message = "Expected target group outputs for both listener keys."
  }
}

run "plan_two_services_mixed_listener_counts" {
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
        service_target_ips = ["198.51.100.20", "198.51.100.21", "198.51.100.22"]
        listeners = {
          https = {
            listener_port = 443
          }
          grpc = {
            listener_port = 8443
            target_port   = 50051
          }
        }
      }
      billing = {
        name               = "example-billing-pls"
        service_target_ips = ["198.51.100.30", "198.51.100.31", "198.51.100.32"]
        listeners = {
          tcp = {
            listener_port = 9443
          }
        }
      }
    }
  }

  assert {
    condition     = length(output.endpoint_service_names) == 2
    error_message = "Expected output values for two endpoint services."
  }

  assert {
    condition     = length(output.nlb_arns) == 2
    error_message = "Expected one NLB per service."
  }

  assert {
    condition     = length(output.listener_arns) == 3 && length(output.target_group_arns) == 3
    error_message = "Expected one listener and target group per listener definition."
  }
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
        name               = "example-invalid-pls"
        service_target_ips = []
        listeners = {
          tcp = {
            listener_port = 443
          }
        }
      }
    }
  }

  expect_failures = [var.pl_services]
}

run "reject_invalid_service_in_mixed_map" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      valid = {
        name               = "example-valid-pls"
        service_target_ips = ["198.51.100.40", "198.51.100.41", "198.51.100.42"]
        listeners = {
          https = {
            listener_port = 443
          }
        }
      }
      invalid = {
        name               = "example-invalid-empty-pls"
        service_target_ips = []
        listeners = {
          tcp = {
            listener_port = 9443
          }
        }
      }
    }
  }

  expect_failures = [var.pl_services]
}

run "reject_multiple_services_with_empty_target_ips" {
  command = plan

  variables {
    account_id = "000000000000"
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = [
      "subnet-00000000000000000",
      "subnet-11111111111111111"
    ]

    pl_services = {
      invalid_a = {
        name               = "example-invalid-a-pls"
        service_target_ips = []
        listeners = {
          tcp = {
            listener_port = 8443
          }
        }
      }
      invalid_b = {
        name               = "example-invalid-b-pls"
        service_target_ips = []
        listeners = {
          https = {
            listener_port = 443
          }
        }
      }
    }
  }

  expect_failures = [var.pl_services]
}