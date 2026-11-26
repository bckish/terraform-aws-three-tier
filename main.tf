terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.49" }
  }
}

provider "aws" { region = var.region }
variable "region" {
  type    = string
  default = "eu-central-1"
}
variable "project" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project))
    error_message = "Use a lowercase project slug of 3–25 characters."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Choose dev, qa or prod."
  }
}
variable "vpc_cidr" {
  type = string
  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 5)) && can(regex("^[0-9.]+/16$", var.vpc_cidr))
    error_message = "Provide a valid IPv4 /16 CIDR."
  }
}
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Provide two distinct availability zones."
  }
}

module "foundation" {
  source      = "./modules/foundation"
  name        = "${var.project}-${var.environment}"
  environment = var.environment
  cidr        = var.vpc_cidr
  zones       = var.availability_zones
}

output "subnets" { value = module.foundation.subnets }
output "storage_public_access_blocked" { value = module.foundation.storage_public_access_blocked }
output "registry_tag_mutability" { value = module.foundation.registry_tag_mutability }
output "tags" { value = module.foundation.tags }
