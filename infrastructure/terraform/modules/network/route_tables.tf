# =========================================
# Public Route Table and Routes
# =========================================

resource "aws_route_table" "public_routes" {
  count  = local.use_existing_public_subnets ? 0 : 1
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
  count                  = local.use_existing_public_subnets ? 0 : 1
  route_table_id         = aws_route_table.public_routes[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.internet_gateway_id
}

# =========================================
# Route Table Associations
# =========================================

resource "aws_route_table_association" "public_subnet_az1_association" {
  count          = local.use_existing_public_subnets ? 0 : 1
  subnet_id      = local.public_subnet_az1_id
  route_table_id = aws_route_table.public_routes[0].id
}

resource "aws_route_table_association" "public_subnet_az2_association" {
  count          = local.use_existing_public_subnets ? 0 : 1
  subnet_id      = local.public_subnet_az2_id
  route_table_id = aws_route_table.public_routes[0].id
}

data "aws_route_table" "existing_public_route" {
  count     = local.use_existing_public_subnets ? 1 : 0
  subnet_id = local.public_subnet_az1_id
}

locals {
  public_route_table_id = local.use_existing_public_subnets ? data.aws_route_table.existing_public_route[0].id : aws_route_table.public_routes[0].id
}
