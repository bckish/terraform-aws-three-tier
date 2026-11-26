terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}
variable "name" { type = string }
variable "environment" { type = string }
variable "cidr" { type = string }
variable "zones" { type = list(string) }

locals {
  tags    = { Project = var.name, Environment = var.environment, ManagedBy = "Terraform" }
  tiers   = ["web", "app", "data"]
  subnets = { for i, pair in setproduct(local.tiers, var.zones) : "${pair[0]}-${pair[1]}" => { tier = pair[0], zone = pair[1], cidr = cidrsubnet(var.cidr, 8, i) } }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = var.name })
}
resource "aws_subnet" "tier" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.zone
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${var.name}-${each.key}", Tier = each.value.tier })
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-private" })
}
resource "aws_route_table_association" "tier" {
  for_each       = aws_subnet.tier
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.name}-artifacts-"
  tags          = local.tags
}
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_ecr_repository" "images" {
  name                 = "${var.name}/services"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

output "subnets" { value = { for name, subnet in aws_subnet.tier : name => { cidr = subnet.cidr_block, public_ip = subnet.map_public_ip_on_launch } } }
output "storage_public_access_blocked" { value = aws_s3_bucket_public_access_block.artifacts.block_public_acls && aws_s3_bucket_public_access_block.artifacts.block_public_policy && aws_s3_bucket_public_access_block.artifacts.ignore_public_acls && aws_s3_bucket_public_access_block.artifacts.restrict_public_buckets }
output "registry_tag_mutability" { value = aws_ecr_repository.images.image_tag_mutability }
output "tags" { value = local.tags }
