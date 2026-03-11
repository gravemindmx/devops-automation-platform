# =========================================
# Public Subnets (Multi-AZ)
# =========================================

resource "aws_subnet" "public_subnet_az1" {
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
