# =========================================
# Public Subnets (Multi-AZ)
# =========================================

data "aws_subnets" "public_subnet_az1_existing" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "cidr-block"
    values = [var.public_subnet_1_cidr]
  }
}

data "aws_subnets" "public_subnet_az2_existing" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "cidr-block"
    values = [var.public_subnet_2_cidr]
  }
}

locals {
  use_existing_public_subnets = length(data.aws_subnets.public_subnet_az1_existing.ids) > 0 && length(data.aws_subnets.public_subnet_az2_existing.ids) > 0
}

data "aws_subnet" "public_subnet_az1_existing" {
  count = local.use_existing_public_subnets ? 1 : 0
  id    = data.aws_subnets.public_subnet_az1_existing.ids[0]
}

data "aws_subnet" "public_subnet_az2_existing" {
  count = local.use_existing_public_subnets ? 1 : 0
  id    = data.aws_subnets.public_subnet_az2_existing.ids[0]
}

resource "aws_subnet" "public_subnet_az1" {
  count                   = local.use_existing_public_subnets ? 0 : 1
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-public-subnet-az1"
      Component = "network"
      Type      = "Public"
      Tier      = "Public"
    }
  )
}

resource "aws_subnet" "public_subnet_az2" {
  count                   = local.use_existing_public_subnets ? 0 : 1
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-public-subnet-az2"
      Component = "network"
      Type      = "Public"
      Tier      = "Public"
    }
  )
}

locals {
  public_subnet_az1_id = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az1_existing[0].id : aws_subnet.public_subnet_az1[0].id
  public_subnet_az2_id = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az2_existing[0].id : aws_subnet.public_subnet_az2[0].id

  public_subnet_az1_cidr = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az1_existing[0].cidr_block : aws_subnet.public_subnet_az1[0].cidr_block
  public_subnet_az2_cidr = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az2_existing[0].cidr_block : aws_subnet.public_subnet_az2[0].cidr_block

  public_subnet_az1_az = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az1_existing[0].availability_zone : aws_subnet.public_subnet_az1[0].availability_zone
  public_subnet_az2_az = local.use_existing_public_subnets ? data.aws_subnet.public_subnet_az2_existing[0].availability_zone : aws_subnet.public_subnet_az2[0].availability_zone
}
