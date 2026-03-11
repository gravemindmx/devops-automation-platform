# Platform Guide

Guia unica para entender, configurar, desplegar y operar la plataforma.

## 1) Arquitectura

La plataforma integra:
- GitHub para eventos de push/PR.
- Jenkins para CI/CD.
- AWS Lambda + API Gateway para automatizacion y notificaciones.
- Jira para gestion de incidentes.
- Teams para notificaciones operativas.

Flujo base:
1. Push/PR en GitHub.
2. Webhook dispara pipeline en Jenkins.
3. Jenkins ejecuta build/test/deploy.
4. Lambda envia notificacion a Teams.
5. En falla, se crea issue en Jira y se notifica.

## 2) Setup Inicial

Prerequisitos:
- Terraform >= 1.0
- AWS CLI v2
- Git
- Credenciales AWS configuradas

Pasos:
1. Ir a `infrastructure/terraform`.
2. Completar `terraform.tfvars` con valores reales.
3. Ejecutar:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

4. Obtener outputs y validar acceso a Jenkins por ALB.
5. Configurar credenciales en Jenkins (`github-token`, `jira-url`, `jira-api-token`, `teams-webhook`, `teams-qa-webhook`).
6. Configurar webhooks de GitHub y Jira hacia Jenkins.

## 3) Despliegue

Despliegue recomendado:
1. Verificar herramientas y credenciales.
2. Ejecutar `terraform plan` y revisar cambios.
3. Aplicar con plan guardado.
4. Validar salud de ALB, Jenkins y Lambdas.

Comandos utiles:

```bash
cd infrastructure/terraform
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

## 4) Operacion y Troubleshooting

Chequeos comunes:

```bash
./scripts/jenkins/health-check.sh
aws logs tail /aws/lambda/teams-notifier --follow
aws elbv2 describe-target-health --target-group-arn <arn>
```

Problemas tipicos:
- Jenkins inaccesible: revisar ALB y target group.
- Webhook no dispara: revisar configuracion y entregas recientes en GitHub/Jira.
- Lambda falla: revisar CloudWatch Logs y variables de entorno.

## 5) Mantenimiento de Documentacion

- No crear archivos historicos de resumen.
- Actualizar este archivo para cambios operativos/arquitectura.

## 6) Referencia Tecnica

### Terraform outputs

Comandos utiles:

```bash
terraform output
terraform output -raw alb_dns_name
terraform output -raw teams_notifier_function_name
terraform output -raw jira_handler_function_name
```

Outputs relevantes:
- `alb_dns_name`
- `jenkins_public_url`
- `teams_notifier_function_name`
- `jira_handler_function_name`
- `webhook_url`

### Interfaces Lambda

`teams-notifier`

Evento esperado:

```json
{
	"source": "github|jenkins|jira",
	"event_type": "push|pull_request|build|failure|resolved",
	"title": "string",
	"description": "string",
	"repository": "string",
	"branch": "string",
	"status": "success|failure|pending",
	"url": "https://...",
	"timestamp": "2024-01-01T00:00:00Z"
}
```

Variables de entorno:

```bash
TEAMS_WEBHOOK_URL
AWS_REGION
LOG_LEVEL
```

`jira-event-handler`

Evento esperado desde Jira:

```json
{
	"webhookEvent": "jira:issue_updated",
	"issue": {
		"key": "DEVOPS-123",
		"fields": {
			"summary": "Issue title",
			"status": {
				"name": "Resolved"
			}
		}
	},
	"changelog": {
		"items": [
			{
				"field": "status",
				"fromString": "To Do",
				"toString": "Resolved"
			}
		]
	}
}
```

Variables de entorno:

```bash
JIRA_URL
JIRA_USER
JIRA_API_TOKEN
TEAMS_WEBHOOK_URL
AWS_REGION
```

### Jenkins pipeline

Stages principales:
- Checkout
- Build
- Test
- Security Scan
- Deploy QA
- Validate
- Success Notification

Credenciales requeridas:
- `github-token`
- `jira-url`
- `jira-api-token`
- `teams-webhook`
- `teams-qa-webhook`

### Webhooks

GitHub:
- Trigger: push y pull_request
- Endpoint: `http://<jenkins-alb-dns>:80/github-webhook/`

Jira:
- Trigger: issue updated
- Endpoint: `http://<jenkins-alb-dns>:80/jira-webhook/`

Teams:
- Metodo: `POST`
- Endpoint: valor configurado en `teams_webhook_url`

### Archivos de configuracion

Terraform:

```hcl
aws_region            = "us-east-1"
vpc_id                = "vpc-..."
jenkins_instance_id   = "i-..."
github_token          = "ghp_..."
jira_url              = "https://example.atlassian.net"
jira_api_token        = "ATATT3..."
teams_webhook_url     = "https://outlook.webhook.office.com/..."
teams_qa_webhook_url  = "https://outlook.webhook.office.com/..."
```

Lambda:

```bash
JIRA_URL=https://example.atlassian.net
JIRA_USER=automation@example.com
JIRA_API_TOKEN=ATATT3...
TEAMS_WEBHOOK_URL=https://outlook.webhook.office.com/...
AWS_REGION=us-east-1
LOG_LEVEL=INFO
```