output "internet_gateway_id" {
  description = "Internet Gateway ID for public internet access"
  value       = aws_internet_gateway.jenkins_public_gateway.id
}

output "public_subnet_az1_id" {
  description = "Public subnet ID in AZ1"
  value       = aws_subnet.public_subnet_az1.id
}

output "public_subnet_az2_id" {
  description = "Public subnet ID in AZ2"
  value       = aws_subnet.public_subnet_az2.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public_routes.id
}

output "public_subnets_info" {
  description = "Information about public subnets"
  value = {
    az1 = {
      subnet_id         = aws_subnet.public_subnet_az1.id
      cidr_block        = aws_subnet.public_subnet_az1.cidr_block
      availability_zone = aws_subnet.public_subnet_az1.availability_zone
    }
    az2 = {
      subnet_id         = aws_subnet.public_subnet_az2.id
      cidr_block        = aws_subnet.public_subnet_az2.cidr_block
      availability_zone = aws_subnet.public_subnet_az2.availability_zone
    }
  }
}
