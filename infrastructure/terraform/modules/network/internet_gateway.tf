# =========================================
# Internet Gateway
# =========================================

data "aws_internet_gateway" "existing" {
  count = local.use_existing_public_subnets ? 1 : 0

  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_internet_gateway" "jenkins_public_gateway" {
  count  = local.use_existing_public_subnets ? 0 : 1
  vpc_id = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-igw"
      Component = "network"
    }
  )
}

locals {
  internet_gateway_id = local.use_existing_public_subnets ? data.aws_internet_gateway.existing[0].id : aws_internet_gateway.jenkins_public_gateway[0].id
}
