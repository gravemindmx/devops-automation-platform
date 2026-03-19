# Plataforma de Automatización DevOps

> **📖 DOCUMENTACIÓN CENTRAL:** [docs/platform-guide.md](docs/platform-guide.md)

---

Este repositorio contiene la **infraestructura como código (IaC)** y los componentes de automatización para CI/CD y notificaciones en AWS.

---

## Flujo Completo

```
terraform apply
       ↓
AWS Lambda + API Gateway + IAM + Jenkins ALB
       ↓
Developer trabaja → Commit o Pull Request hacia qa o prod
       ↓
GitHub Webhook → Jenkins Pipeline  (automático)
       ↓
Build (pip + zip)  →  Test (pytest)  →  Deploy QA (Lambda)
       ↓
    Resultado
   ┌────────────────────────────────┐
SUCCESS                           FAIL
   ↓                                ↓
Lambda invoke                  Lambda invoke
(build_success)               (build_failure)
       ↓                                ↓
Teams ✅ Build OK + QA          Teams ❌ Falla + logs/build URL
```

---

## Componentes

| Componente | Descripción |
|---|---|
| `infrastructure/terraform/` | IaC: red, Jenkins, Lambdas, API Gateway, IAM |
| `services/teams-notifier/` | Lambda Python — notifica Teams en eventos CI/CD |
| `jenkins/Jenkinsfile` | Pipeline completo: build, test, deploy QA, notificaciones |
| `scripts/jenkins/` | Scripts de health-check e integraciones auxiliares |

---

## Quick Start

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Completar terraform.tfvars con valores reales
terraform init && terraform plan -out=tfplan && terraform apply tfplan
terraform output   # Copiar webhook_url
```

Configuración completa: [docs/platform-guide.md](docs/platform-guide.md)

JSON de tarjeta para Power Automate: [docs/power-automate-adaptive-card.json](docs/power-automate-adaptive-card.json)
JSON de tarjeta para Power Automate (solo fallas): [docs/power-automate-adaptive-card-failure.json](docs/power-automate-adaptive-card-failure.json)

---

## Autor

Alberto Juan Gabino
