output "internet_gateway_id" {
  description = "Internet Gateway ID for public internet access"
  value       = local.internet_gateway_id
}

output "public_subnet_az1_id" {
  description = "Public subnet ID in AZ1"
  value       = local.public_subnet_az1_id
}

output "public_subnet_az2_id" {
  description = "Public subnet ID in AZ2"
  value       = local.public_subnet_az2_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [local.public_subnet_az1_id, local.public_subnet_az2_id]
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = local.public_route_table_id
}

output "public_subnets_info" {
  description = "Information about public subnets"
  value = {
    az1 = {
      subnet_id         = local.public_subnet_az1_id
      cidr_block        = local.public_subnet_az1_cidr
      availability_zone = local.public_subnet_az1_az
    }
    az2 = {
      subnet_id         = local.public_subnet_az2_id
      cidr_block        = local.public_subnet_az2_cidr
      availability_zone = local.public_subnet_az2_az
    }
  }
}
