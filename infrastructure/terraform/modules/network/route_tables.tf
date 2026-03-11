# =========================================
# Public Route Table and Routes
# =========================================

resource "aws_route_table" "public_routes" {
  vpc_id = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-public-rt"
      Component = "network"
      Tier      = "Public"
    }
  )
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_routes.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.jenkins_public_gateway.id
}

# =========================================
# Route Table Associations
# =========================================

resource "aws_route_table_association" "public_subnet_az1_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_routes.id
}

resource "aws_route_table_association" "public_subnet_az2_association" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_routes.id
}
