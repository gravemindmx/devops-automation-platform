# Platform Guide

Guía única para entender, configurar, desplegar y operar la plataforma.

---

## 1) Arquitectura y Flujo Completo

### Componentes

| Componente | Rol |
|---|---|
| **Terraform** | Provisiona toda la infraestructura AWS (red, Jenkins ALB, Lambdas, API Gateway, IAM) |
| **Jenkins** | Orquestador CI/CD; recibe webhooks de GitHub y ejecuta el pipeline completo |
| **AWS Lambda – teams-notifier** | Envía notificaciones a Microsoft Teams (éxito, falla, resolución) |
| **AWS Lambda – jira-event-handler** | Procesa webhooks de Jira y notifica en Teams cuando un ticket se resuelve |
| **API Gateway** | Punto de entrada HTTP para ambas Lambdas (`POST /notify` y `POST /jira`) |
| **GitHub** | Repositorio de código; dispara Jenkins vía webhook en merge a `develop` |
| **Jira** | Gestión de incidentes; dispara jira-event-handler vía webhook al resolver tickets |
| **Microsoft Teams** | Canal de notificaciones operativas |

---

### Flujo completo

```
┌─────────────────────────────────────────────────────────────────┐
│  1. INFRAESTRUCTURA (una vez, o al cambiar IaC)                 │
│                                                                 │
│  terraform apply                                                │
│       ↓                                                         │
│  AWS Lambda (teams-notifier + jira-event-handler)               │
│  API Gateway  →  POST /notify  →  teams-notifier                │
│                  POST /jira    →  jira-event-handler            │
│  IAM roles + Jenkins ALB                                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  2. INICIO DE TRABAJO (opcional, vía pipeline parametrizado)    │
│                                                                 │
│  Jenkins Pipeline  (CREATE_BRANCH=true, BRANCH_TO_CREATE=...)   │
│       ↓                                                         │
│  Jenkins crea rama en GitHub (git push origin feature/...)      │
│       ↓                                                         │
│  Developer trabaja en la rama                                   │
│       ↓                                                         │
│  Pull Request → Merge a develop                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  3. CI/CD AUTOMÁTICO (disparado por merge a develop)            │
│                                                                 │
│  GitHub Webhook  →  Jenkins (githubPush trigger)                │
│       ↓                                                         │
│  Stage: Checkout                                                │
│       ↓                                                         │
│  Stage: Build                                                   │
│   pip install + zip  (teams-notifier.zip, jira-handler.zip)     │
│       ↓                                                         │
│  Stage: Test                                                    │
│   python -m pytest  (teams-notifier + jira-event-handler)       │
│       ↓                                                         │
│  Stage: Security Scan  (auditoría de dependencias)              │
│       ↓                                                         │
│  Stage: Deploy QA                                               │
│   aws lambda update-function-code  (ambas Lambdas QA)           │
│       ↓                                                         │
│  Stage: Validation  (health check Lambda QA)                    │
│       ↓                                                         │
│             ┌──────────────── Resultado ─────────────────┐      │
│             │                                            │      │
│           SUCCESS                                      FAIL      │
│             ↓                                            ↓      │
│   Lambda invoke                              curl Jira REST API  │
│   (event: build_success)                     → Crea ticket Bug   │
│             ↓                                            ↓      │
│   Teams: ✅ Build OK                         Lambda invoke       │
│           Deployed to QA                     (event: build_fail) │
│                                                          ↓      │
│                                              Teams: ❌ Build FAIL│
│                                                   + link Jira   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  4. RESOLUCIÓN DE INCIDENTE (disparado por Jira)                │
│                                                                 │
│  Equipo corrige el error en su rama                             │
│       ↓                                                         │
│  Ticket Jira → estado DONE / RESOLVED / CLOSED                  │
│       ↓                                                         │
│  Jira Webhook  →  API Gateway  POST /jira                       │
│       ↓                                                         │
│  Lambda: jira-event-handler                                     │
│   (event: jira:issue_updated, status → DONE)                    │
│       ↓                                                         │
│  Teams: ✅ Ticket RESUELTO  (quién, cuánto tardó)              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2) Estructura del Repositorio

```
devops-automation-platform/
├── infrastructure/
│   └── terraform/
│       ├── main.tf                    # Raíz: ensambla todos los módulos
│       ├── variables.tf / outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       └── modules/
│           ├── network/               # VPC, subnets, route tables, IGW
│           ├── jenkins/               # ALB, security groups, IAM para Jenkins EC2
│           ├── lambda/                # Lambda teams-notifier + IAM
│           ├── apigateway/            # HTTP API: POST /notify + POST /jira
│           └── jira-handler/          # Lambda jira-event-handler + IAM
├── services/
│   ├── teams-notifier/
│   │   ├── src/lambda.py              # Handler: build_success/failure, deployment, jira_resolved
│   │   ├── tests/test_lambda.py       # 3 pruebas pytest
│   │   └── config/                   # requirements.txt, setup.py, Makefile
│   └── jira-event-handler/
│       ├── src/handler.py             # Handler: issue_updated → resolución → Teams
│       ├── tests/test_handler.py      # 3 pruebas pytest
│       └── config/
├── jenkins/
│   └── Jenkinsfile                    # Pipeline completo con triggers y manejo de errores
├── scripts/
│   └── jenkins/
│       ├── health-check.sh            # Valida Lambda QA y API Gateway
│       └── jira/create-jira-issue.sh  # Crea ticket Jira desde CLI
└── docs/
    ├── README.md
    └── platform-guide.md             # (este archivo)
```

---

## 3) Setup Inicial

### Prerrequisitos

- Terraform >= 1.0
- AWS CLI v2 configurado con credenciales
- Python 3.11+ con pip
- Git
- Cuenta Jenkins con los plugins: **GitHub**, **Pipeline**, **Credentials Binding**

### Paso 1 — Infraestructura AWS

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con los valores reales
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output   # Guardar webhook_url y jira_webhook_url
```

### Recomendado — Secretos por entorno (sin `.tfvars`)

Mantén secretos fuera de archivos versionados y cárgalos como variables de entorno `TF_VAR_*`.

PowerShell (Windows):

```powershell
$env:TF_VAR_github_token = "<github_pat>"
$env:TF_VAR_jira_api_token = "<jira_api_token>"
$env:TF_VAR_teams_webhook_url = "<teams_webhook_general>"
$env:TF_VAR_teams_qa_webhook_url = "<teams_webhook_qa>"

terraform -chdir=infrastructure/terraform plan -out=tfplan
terraform -chdir=infrastructure/terraform apply tfplan
```

Bash (Linux/macOS):

```bash
export TF_VAR_github_token="<github_pat>"
export TF_VAR_jira_api_token="<jira_api_token>"
export TF_VAR_teams_webhook_url="<teams_webhook_general>"
export TF_VAR_teams_qa_webhook_url="<teams_webhook_qa>"

terraform -chdir=infrastructure/terraform plan -out=tfplan
terraform -chdir=infrastructure/terraform apply tfplan
```

En Jenkins, usa credenciales y expórtalas como `TF_VAR_*` durante el stage de Terraform.

Outputs clave:

| Output | Uso |
|---|---|
| `webhook_url` | URL para el webhook de Jenkins (API Gateway `POST /notify`) |
| `jira_webhook_url` | URL a configurar en Jira webhooks (`POST /jira`) |
| `jenkins_public_url` | URL pública de Jenkins vía ALB |

### Paso 2 — Credenciales en Jenkins

Configurar en **Manage Jenkins → Credentials**:

| ID | Tipo | Descripción |
|---|---|---|
| `github-token` | Secret text | GitHub Personal Access Token (scope: `repo`) |
| `jira-url` | Secret text | URL base de Jira (ej. `https://tu-org.atlassian.net`) |
| `jira-api-token` | Secret text | API Token de Jira |
| `teams-webhook` | Secret text | Webhook URL de Teams (canal principal) |
| `teams-qa-webhook` | Secret text | Webhook URL de Teams (canal QA) |

### Paso 3 — Webhook de GitHub

En el repositorio GitHub → **Settings → Webhooks → Add webhook**:

- **Payload URL:** URL de Jenkins + `/github-webhook/`
- **Content type:** `application/json`
- **Events:** `Push`, `Pull requests`

### Paso 4 — Webhook de Jira

En Jira → **Configuración → System → WebHooks → Create**:

- **URL:** valor de `jira_webhook_url` del `terraform output`
- **Events:** Issue updated (status change)

### Paso 5 — Crear pipeline en Jenkins

1. **New Item → Pipeline**
2. En **Build Triggers:** activar `GitHub hook trigger for GITScm polling`
3. En **Pipeline:** seleccionar `Pipeline script from SCM` → apuntar al repo, rama `develop`, archivo `jenkins/Jenkinsfile`

---

## 4) Uso del Pipeline

### Disparo automático (merge a develop)

Cada merge a `develop` dispara el pipeline completo automáticamente vía webhook de GitHub.

### Crear rama de feature desde Jenkins (opcional)

Ejecutar el pipeline manualmente con parámetros:

| Parámetro | Valor |
|---|---|
| `CREATE_BRANCH` | `true` |
| `BRANCH_TO_CREATE` | `feature/PROJ-123-mi-feature` |

Jenkins creará y pusheará la rama en GitHub usando el token `github-token`.

### Eventos que Teams puede recibir

| `event_type` | Cuándo se envía |
|---|---|
| `build_success` | Pipeline QA exitoso |
| `build_failure` | Cualquier stage falla (incluye link a ticket Jira) |
| `deployment_success` | Despliegue exitoso |
| `deployment_failure` | Despliegue fallido |
| `jira_resolved` | Ticket resuelto manualmente vía Lambda |
| *(desde Jira webhook)* | Ticket cambia a DONE/RESOLVED/CLOSED |

---

## 5) Despliegue de Lambdas

Las Lambdas se empacan y despliegan automáticamente desde el Jenkinsfile. Para despliegue manual:

```bash
# Empacar teams-notifier
pip install -r services/teams-notifier/config/requirements.txt \
    -t services/teams-notifier/package/ --quiet
cp -r services/teams-notifier/src/. services/teams-notifier/package/
cd services/teams-notifier && zip -r teams-notifier.zip package/ -x "*.pyc" && cd ../..

# Desplegar
aws lambda update-function-code \
    --function-name devops-platform-teams-notifier \
    --zip-file fileb://services/teams-notifier/teams-notifier.zip \
    --region us-east-1

# Verificar
aws lambda get-function --function-name devops-platform-teams-notifier
```

---

## 6) Operación y Troubleshooting

### Health checks

```bash
# Verificar Lambda QA y API Gateway
./scripts/jenkins/health-check.sh teams-notifier-qa us-east-1 <api-gateway-url>

# Ver logs en tiempo real
aws logs tail /aws/lambda/devops-platform-teams-notifier --follow
aws logs tail /aws/lambda/devops-platform-jira-event-handler --follow

# Estado del target group de Jenkins
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Pruebas locales

```bash
# Teams Notifier
python -m pytest services/teams-notifier/tests/ -v

# Jira Event Handler
python -m pytest services/jira-event-handler/tests/ -v
```

### Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Pipeline no se dispara con el merge | Webhook de GitHub mal configurado | Revisar `Settings → Webhooks` en GitHub; verificar entregas recientes |
| Lambda falla con env var missing | Variables de entorno no configuradas en Terraform | Revisar `terraform.tfvars` y re-aplicar |
| Jira webhook no llega a la Lambda | URL `jira_webhook_url` incorrecta | Ejecutar `terraform output jira_webhook_url` y actualizar en Jira |
| Ticket Jira no se crea en falla | Token Jira expirado o credencial mal configurada | Rotar el API Token y actualizar la credencial `jira-api-token` en Jenkins |
| Teams no recibe notificación | Webhook de Teams expirado | Regenerar el webhook en el canal Teams y actualizar credencial |
| Jenkins no puede crear rama | Token GitHub sin permisos `repo` | Regenerar token con scope `repo` y actualizar credencial `github-token` |

---

## 7) Mantenimiento de Documentación

- Actualizar **este archivo** para cambios operativos o de arquitectura.
- No crear archivos históricos de resumen.
- Mantener `docs/README.md` solo como índice.