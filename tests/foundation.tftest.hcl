mock_provider "aws" {}
variables {
  project            = "fintech-lab"
  environment        = "qa"
  vpc_cidr           = "10.42.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
}
run "private_foundation" {
  command = plan
  assert {
    condition     = length(output.subnets) == 6 && alltrue([for subnet in values(output.subnets) : !subnet.public_ip]) && length(distinct([for subnet in values(output.subnets) : subnet.cidr])) == 6
    error_message = "Three tiers must have six distinct private subnets."
  }
  assert {
    condition     = output.storage_public_access_blocked && output.registry_tag_mutability == "IMMUTABLE" && output.tags.Environment == "qa"
    error_message = "Storage, image and environment controls are required."
  }
}
run "reject_single_zone" {
  command = plan
  variables { availability_zones = ["eu-central-1a", "eu-central-1a"] }
  expect_failures = [var.availability_zones]
}
run "reject_invalid_environment" {
  command = plan
  variables { environment = "other" }
  expect_failures = [var.environment]
}
