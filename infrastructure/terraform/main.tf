module "network" {
  source = "./modules/network"

  vpc_id               = var.vpc_id
  aws_region           = var.aws_region
  project_name         = var.project_name
  public_subnet_1_cidr = "10.30.0.0/24"
  public_subnet_2_cidr = "10.30.1.0/24"
  common_tags          = var.common_tags
}

module "lambda" {
  source = "./modules/lambda"

  teams_webhook_url = var.teams_webhook_url
  lambda_zip_path   = "${path.root}/../../services/teams-notifier/teams-notifier.zip"
  project_name      = var.project_name
  common_tags       = var.common_tags
}

module "api" {
  source = "./modules/apigateway"

  lambda_invoke_arn      = module.lambda.invoke_arn
  jira_lambda_invoke_arn = module.jira_handler.jira_handler_invoke_arn
  project_name           = var.project_name
  common_tags            = var.common_tags
}

module "jira_handler" {
  source = "./modules/jira-handler"

  jira_url          = var.jira_url
  jira_api_token    = var.jira_api_token
  teams_webhook_url = var.teams_qa_webhook_url
  lambda_zip_path   = "${path.root}/../../services/jira-event-handler/jira-handler.zip"
  project_name      = var.project_name
  common_tags       = var.common_tags
}

module "jenkins" {
  source = "./modules/jenkins"

  # AWS Configuration
  aws_region = var.aws_region

  # Existing Infrastructure References
  jenkins_instance_id = var.jenkins_instance_id
  vpc_id              = var.vpc_id
  private_subnet_id   = var.private_subnet_id

  # Public subnets (created by network module)
  public_subnet_ids = module.network.public_subnet_ids

  # ALB Configuration
  enable_load_balancer = var.enable_load_balancer
  alb_port             = var.alb_port

  # Jenkins Configuration
  jenkins_port = var.jenkins_port

  # Tagging & Naming
  project_name = var.project_name
  common_tags  = var.common_tags
}