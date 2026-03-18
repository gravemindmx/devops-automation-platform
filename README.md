# Plataforma de Automatización DevOps

> **📖 DOCUMENTACIÓN CENTRAL:** [docs/platform-guide.md](docs/platform-guide.md)

---

Este repositorio contiene la **infraestructura como código (IaC)** y los componentes de automatización para CI/CD, notificaciones y gestión de incidentes en AWS.

---

## Flujo Completo

```
terraform apply
       ↓
AWS Lambda + API Gateway + IAM + Jenkins ALB
       ↓
Developer trabaja → Pull Request → Merge a develop
       ↓
GitHub Webhook → Jenkins Pipeline  (automático)
       ↓
Build (pip + zip)  →  Test (pytest)  →  Deploy QA (Lambda)
       ↓
    Resultado
   ┌────────────────────────────────┐
SUCCESS                           FAIL
   ↓                                ↓
Lambda invoke                  Crea ticket Jira
(build_success)                     ↓
   ↓                           Lambda invoke (build_failure)
Teams ✅ Build OK + QA          Teams ❌ Falla + link Jira
                                    ↓
                               Equipo corrige → ticket RESUELTO
                                    ↓
                               Jira Webhook → API Gateway POST /jira
                                    ↓
                               Lambda jira-event-handler
                                    ↓
                               Teams ✅ Ticket resuelto
```

---

## Componentes

| Componente | Descripción |
|---|---|
| `infrastructure/terraform/` | IaC: red, Jenkins, Lambdas, API Gateway, IAM |
| `services/teams-notifier/` | Lambda Python — notifica Teams en eventos CI/CD |
| `services/jira-event-handler/` | Lambda Python — procesa webhooks Jira → Teams |
| `jenkins/Jenkinsfile` | Pipeline completo: build, test, deploy QA, notificaciones |
| `scripts/jenkins/` | Scripts de health-check y creación de tickets Jira |

---

## Quick Start

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Completar terraform.tfvars con valores reales
terraform init && terraform plan -out=tfplan && terraform apply tfplan
terraform output   # Copiar webhook_url y jira_webhook_url
```

Configuración completa: [docs/platform-guide.md](docs/platform-guide.md)

---

## Autor

Alberto Juan Gabino
