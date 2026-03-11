# =========================================
# Internet Gateway
# =========================================

resource "aws_internet_gateway" "jenkins_public_gateway" {
  vpc_id = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-igw"
      Component = "network"
    }
  )
}
