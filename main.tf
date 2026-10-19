terraform { required_version = ">= 1.6.0" }
variable "project" { type = string, default = "three-tier" }
locals { tags = { Project = var.project, ManagedBy = "Terraform" } }
output "tags" { value = local.tags }
