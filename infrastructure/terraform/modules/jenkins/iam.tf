# =========================================
# Jenkins IAM Role & Policies
# =========================================

# IAM Role para Jenkins EC2
resource "aws_iam_role" "jenkins_instance_role" {
  name_prefix = "jenkins-instance-role-"
  description = "IAM role for Jenkins EC2 instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-jenkins-role"
      Component = "iam"
    }
  )
}

# Inline Policy: Jenkins Permissions
resource "aws_iam_role_policy" "jenkins_instance_policy" {
  name_prefix = "jenkins-policy-"
  role        = aws_iam_role.jenkins_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Management"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "SSMParameterStore"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile para Jenkins EC2
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name_prefix = "jenkins-profile-"
  role        = aws_iam_role.jenkins_instance_role.name
}
