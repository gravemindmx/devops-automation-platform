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
| **GitHub** | Repositorio de código; dispara Jenkins vía webhook en commits o PR merges a `qa` y `prod` |
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
│  2. CI/CD AUTOMÁTICO (disparado por webhook en qa o prod)       │
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
│  3. RESOLUCIÓN DE INCIDENTE (disparado por Jira)                │
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

## 3) Setup Inicial (Paso a Paso)

Esta sección está pensada para que cualquier persona pueda levantar el proyecto desde cero.

### 3.1 Prerrequisitos

- Terraform >= 1.0
- AWS CLI v2 configurado (`aws configure`)
- Python 3.11+
- Git
- Jenkins con plugins: **GitHub**, **Pipeline**, **Credentials Binding**

Plugins Jenkins recomendados para este proyecto:

Requeridos (mínimo para ejecutar el pipeline actual):

- Git plugin
- GitHub plugin
- Pipeline
- Pipeline: Stage View
- Credentials
- Credentials Binding
- SSH Agent (si usas autenticación por SSH hacia GitHub)

Muy recomendados (operación estable):

- Timestamper (timestamps en logs)
- ANSI Color (salida más legible)
- Workspace Cleanup (limpieza de workspace)

Requeridos para migrar a Organization Folder (multirepo):

- GitHub Branch Source
- Branch API
- SCM API
- Folder plugin

Validación rápida local:

```bash
terraform -version
aws --version
python --version
git --version
```

### 3.2 Elige una sola ruta de ejecución (Local o Jenkins)

Para evitar confusión, usa solo una ruta por ejecución:

| Escenario | Ruta recomendada | Dónde van los secretos |
|---|---|---|
| Primera instalación / pruebas en tu equipo | **Local (PowerShell/Bash)** | Variables de entorno `TF_VAR_*` en tu terminal |
| Despliegue recurrente de equipo / CI/CD | **Jenkins Pipeline** | Jenkins Credentials (inyectadas como `TF_VAR_*` en el pipeline) |

Regla operativa:

- Si ejecutas Terraform en tu laptop: configura `TF_VAR_*` localmente y ejecuta `terraform` tú.
- Si ejecuta Terraform Jenkins: configura credenciales en Jenkins y dispara el job.
- No necesitas hacer ambos al mismo tiempo para el mismo deploy.

Nota importante: las secciones siguientes indican explícitamente si aplican a **Solo Local**, **Solo Jenkins** o **Ambas rutas**.

Checklist rápido por ruta:

Ruta Local:

1. Completar `terraform.tfvars` solo con valores no sensibles.
2. Exportar `TF_VAR_github_token`, `TF_VAR_jira_api_token`, `TF_VAR_teams_webhook_url`, `TF_VAR_teams_qa_webhook_url`.
3. Ejecutar `terraform init/plan/apply` desde `infrastructure/terraform`.

Ruta Jenkins:

1. Completar `terraform.tfvars` (no sensible) en el repositorio.
2. Cargar secrets en Jenkins Credentials (`github-token`, `jira-api-token`, `teams-webhook`, `teams-qa-webhook`, `jira-url`).
3. Ejecutar pipeline con `APPLY_TERRAFORM=true`.

### 3.3 Variables: qué se configura y dónde

No todos los valores se configuran en el mismo lugar.

| Variable | Requerida | Dónde configurarla | Ejemplo |
|---|---|---|---|
| `aws_region` | Sí | `terraform.tfvars` | `us-east-1` |
| `vpc_id` | Sí | `terraform.tfvars` | `vpc-xxxxxxxx` |
| `jenkins_instance_id` | Sí | `terraform.tfvars` | `i-xxxxxxxx` |
| `private_subnet_id` | Sí | `terraform.tfvars` | `subnet-xxxxxxxx` |
| `github_org` | Sí | `terraform.tfvars` | `mi-org` |
| `github_repo` | Sí | `terraform.tfvars` | `devops-automation-platform` |
| `jira_url` | Sí | `terraform.tfvars` o Jenkins cred `jira-url` | `https://mi-org.atlassian.net` |
| `jira_project_key` | Sí | `terraform.tfvars` | `DEVOPS` |
| `jira_assignee_user` | Opcional | `terraform.tfvars` | `qa-team` |
| `qa_environment_url` | Opcional | `terraform.tfvars` | `https://qa-api.example.com` |
| `github_token` | Sí | `TF_VAR_github_token` o Jenkins cred `github-token` | token |
| `jira_api_token` | Sí | `TF_VAR_jira_api_token` o Jenkins cred `jira-api-token` | token |
| `teams_webhook_url` | Sí | `TF_VAR_teams_webhook_url` o Jenkins cred `teams-webhook` | URL webhook |
| `teams_qa_webhook_url` | Sí | `TF_VAR_teams_qa_webhook_url` o Jenkins cred `teams-qa-webhook` | URL webhook |

Regla: secretos en variables de entorno/Jenkins, no en archivos versionados.

### 3.3.1 De dónde sacar cada variable

AWS:

- `aws_region`: región donde están tus recursos AWS.
- `vpc_id`: en consola AWS VPC -> Your VPCs.
- `private_subnet_id`: en consola AWS VPC -> Subnets (la subnet privada donde vive Jenkins).
- `jenkins_instance_id`: en consola EC2 -> Instances (ID de la instancia Jenkins).

GitHub:

- `github_org`: nombre de tu organización o usuario dueño del repo.
- `github_repo`: nombre del repositorio.
- `github_token` (secreto): GitHub -> Settings -> Developer settings -> Personal access tokens (scope mínimo: `repo`).

Jira:

- `jira_url`: URL base de tu instancia, por ejemplo `https://tu-org.atlassian.net`.
- `jira_project_key`: Jira -> Project settings -> Details (Project key).
- `jira_assignee_user`: usuario/equipo por defecto para tickets automáticos.
- `jira_api_token` (secreto): Atlassian account -> Security -> API tokens.

Teams:

- `teams_webhook_url` (secreto): en el canal principal, crear Incoming Webhook y copiar URL.
- `teams_qa_webhook_url` (secreto): en canal QA, crear Incoming Webhook y copiar URL.

### 3.3.2 Dónde configurar cada cosa (resumen operativo)

En `terraform.tfvars` (no sensible):

- `aws_region`
- `vpc_id`
- `jenkins_instance_id`
- `private_subnet_id`
- `github_org`
- `github_repo`
- `jira_url`
- `jira_project_key`
- `jira_assignee_user`
- `qa_environment_url`

En variables de entorno local (`TF_VAR_*`):

- `TF_VAR_github_token`
- `TF_VAR_jira_api_token`
- `TF_VAR_teams_webhook_url`
- `TF_VAR_teams_qa_webhook_url`

En Jenkins Credentials:

- `github-token`
- `jira-url`
- `jira-api-token`
- `teams-webhook`
- `teams-qa-webhook`

### 3.3.3 Variables del runtime del pipeline (Jenkinsfile)

Estas variables no van en `terraform.tfvars`; viven en Jenkins (credenciales, parámetros o `environment` del pipeline).

| Variable | Fuente | Dónde se define | Valor recomendado |
|---|---|---|---|
| `JIRA_URL` | Credencial Jenkins | `jira-url` | `https://<tu-org>.atlassian.net` |
| `JIRA_API_TOKEN` | Credencial Jenkins | `jira-api-token` | API token de cuenta técnica Jira |
| `JIRA_DEFAULT_USER_EMAIL` | Jenkinsfile (`environment`) | `jenkins/Jenkinsfile` | `infraestructura@imony.mx` |
| `JIRA_PROJECT_KEY` | Jenkinsfile (`environment`) | `jenkins/Jenkinsfile` | `NFRTST` |
| `TEAMS_WEBHOOK` | Credencial Jenkins | `teams-webhook` | Webhook Teams canal principal |
| `TEAMS_QA_WEBHOOK` | Credencial Jenkins | `teams-qa-webhook` | Webhook Teams canal QA |
| `LAMBDA_FUNCTION` | Jenkinsfile (`environment`) | `jenkins/Jenkinsfile` | `devops-platform-teams-notifier` |
| `QA_JIRA_HANDLER_FUNCTION` | Jenkinsfile (`environment`) | `jenkins/Jenkinsfile` | `devops-platform-jira-event-handler` |
| `AWS_REGION` | Jenkinsfile (`environment`) | `jenkins/Jenkinsfile` | `us-east-1` |
| `JIRA_USER_EMAIL` | Parámetro Jenkins | parámetro de job | opcional, se ignora si difiere de la cuenta técnica |
| `APP_REPO_URL` | Parámetro Jenkins | parámetro de job | URL del repo app (repo 2) |
| `APP_REPO_BRANCH` | Parámetro Jenkins | parámetro de job | `qa` |
| `RUN_APP_REPO_TESTS` | Parámetro Jenkins | parámetro de job | `true` para validar repo app |
| `APPLY_TERRAFORM` | Parámetro Jenkins | parámetro de job | `true` solo para provisionar/actualizar infra |

### 3.4 Crear y completar `terraform.tfvars` (Ambas rutas)

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` con valores no sensibles (IDs y configuración funcional).

### 3.5 Exportar secretos por entorno (Solo Local)

Aplica solo si tú ejecutas Terraform desde tu terminal.

PowerShell (Windows):

```powershell
$env:TF_VAR_github_token = "<github_pat>"
$env:TF_VAR_jira_api_token = "<jira_api_token>"
$env:TF_VAR_teams_webhook_url = "<teams_webhook_general>"
$env:TF_VAR_teams_qa_webhook_url = "<teams_webhook_qa>"
```

Bash (Linux/macOS):

```bash
export TF_VAR_github_token="<github_pat>"
export TF_VAR_jira_api_token="<jira_api_token>"
export TF_VAR_teams_webhook_url="<teams_webhook_general>"
export TF_VAR_teams_qa_webhook_url="<teams_webhook_qa>"
```

### 3.6 Desplegar infraestructura con Terraform (Solo Local)

Aplica solo para despliegue manual desde tu equipo.

```bash
terraform -chdir=infrastructure/terraform init
terraform -chdir=infrastructure/terraform plan -out=tfplan
terraform -chdir=infrastructure/terraform apply tfplan
terraform -chdir=infrastructure/terraform output
```

Outputs clave:

| Output | Uso |
|---|---|
| `webhook_url` | Endpoint API Gateway para integración de notificaciones |
| `jira_webhook_url` | Endpoint API Gateway para webhook de Jira (`POST /jira`) |
| `jenkins_public_url` | URL pública de Jenkins por ALB |

### 3.7 Configurar Jenkins (Solo Jenkins)

Aplica solo si Jenkins ejecutará el pipeline y/o Terraform.

La configuración soporta dos modos sin romper compatibilidad:

- Job Pipeline clásico (1 repo específico).
- GitHub Organization Folder (múltiples repos, descubrimiento automático).

En **Manage Jenkins → Credentials**, crear:

| ID | Tipo | Valor |
|---|---|---|
| `github-token` | Secret text | GitHub PAT con scope `repo` |
| `jira-url` | Secret text | URL base Jira |
| `jira-api-token` | Secret text | API token Jira |
| `teams-webhook` | Secret text | Webhook Teams canal principal |
| `teams-qa-webhook` | Secret text | Webhook Teams canal QA |

Tipo exacto recomendado en Jenkins (para este Jenkinsfile):

- Scope: `Global`.
- Dominio: `Global credentials (unrestricted)`.
- `github-token`: `Secret text`.
- `jira-url`: `Secret text`.
- `jira-api-token`: `Secret text`.
- `teams-webhook`: `Secret text`.
- `teams-qa-webhook`: `Secret text`.

Campos exactos al crear cada credencial `Secret text`:

- `Scope`: `Global`.
- `Secret`: el valor real (token o URL webhook).
- `ID`: debe coincidir exactamente con el ID esperado por el Jenkinsfile.
- `Description`: texto libre para identificar la credencial.

Plantilla por credencial (copiar y crear una por una):

1. GitHub token
    - `Kind`: `Secret text`
    - `Scope`: `Global`
    - `Secret`: tu GitHub PAT (o token equivalente)
    - `ID`: `github-token`
    - `Description`: `GitHub PAT for pipeline git operations`

2. Jira URL
    - `Kind`: `Secret text`
    - `Scope`: `Global`
    - `Secret`: `https://tu-org.atlassian.net`
    - `ID`: `jira-url`
    - `Description`: `Jira base URL`

3. Jira API token
    - `Kind`: `Secret text`
    - `Scope`: `Global`
    - `Secret`: token API de Jira
    - `ID`: `jira-api-token`
    - `Description`: `Jira API token for incident creation`

4. Teams webhook principal
    - `Kind`: `Secret text`
    - `Scope`: `Global`
    - `Secret`: URL del Incoming Webhook del canal principal
    - `ID`: `teams-webhook`
    - `Description`: `Teams webhook for main notifications`

5. Teams webhook QA
    - `Kind`: `Secret text`
    - `Scope`: `Global`
    - `Secret`: URL del Incoming Webhook del canal QA
    - `ID`: `teams-qa-webhook`
    - `Description`: `Teams webhook for QA notifications`

Validación rápida (obligatoria):

- Si el `ID` no coincide exactamente, Jenkins fallará con "Credentials not found".
- No uses `Secret file` para estas variables; este pipeline espera `Secret text`.

Uso en pipeline:

- `github-token`: creación de ramas y autenticación Git HTTPS.
- `jira-url` + `jira-api-token`: creación automática de ticket en falla.
- `teams-webhook` + `teams-qa-webhook`: notificaciones de build/despliegue.

Luego crear el job Pipeline:

1. **New Item → Pipeline**
2. Activar trigger: `GitHub hook trigger for GITScm polling`
3. **Pipeline script from SCM**
4. Repositorio: este repo
5. Rama: `qa` (y/o crear job equivalente para `prod`)
6. Script path: `jenkins/Jenkinsfile`

Si usarás Terraform desde Jenkins, ejecutar el job con:

- `APPLY_TERRAFORM=true`

Para validar primero en un solo repositorio (piloto recomendado):

- `LOCK_SINGLE_REPO=true`
- `LOCK_GITHUB_ORG=gravemindmx`
- `LOCK_GITHUB_REPO=devops-automation-platform`

Con este modo, el pipeline falla si el SCM del job apunta a otro repositorio.

### 3.7.1 Migrar a Organization Folder sin romper flujo actual (Solo Jenkins)

Objetivo: activar descubrimiento por organización sin apagar tu job actual hasta validar.

1. Mantén tu job Pipeline actual activo como respaldo.
2. Instala/verifica plugins: `GitHub Branch Source`, `Pipeline`, `Credentials Binding`.
3. Crea credencial para GitHub Organization Folder (separada de `github-token`):
    - Opción A (recomendada): `GitHub App` credential.
    - Opción B: `Username with password` (username GitHub, password = PAT).
    - Permisos mínimos: lectura de repos + metadata + administración de webhooks.
4. En Jenkins: `New Item` -> `GitHub Organization`.
5. En `GitHub Organization`, configura:
    - Owner: tu organización.
    - Credentials: credencial GitHub creada.
    - Repository Discovery: `All repositories` o por tópico/patrón.
    - Branch/PR discovery según tu flujo.
    - Script Path: `jenkins/Jenkinsfile`.
6. Ejecuta un `Scan Organization Now` y confirma que se crean jobs por repo/branch.
7. Prueba un repo piloto (commit o PR merge a `qa`) y valida Build/Test/Deploy/Notificaciones.
8. Cuando el piloto esté estable, migra el resto de repos y recién entonces depreca el job clásico.

Notas de compatibilidad del Jenkinsfile:

- Nuevo modo piloto por parámetros:
    - `LOCK_SINGLE_REPO=true` fuerza ejecución en un único repo.
    - `LOCK_GITHUB_ORG` y `LOCK_GITHUB_REPO` definen el repo permitido.
    - Si el checkout corresponde a otro repo, el build falla para evitar despliegues cruzados.
- El pipeline detecta `org/repo` desde `remote.origin.url` (modo Organization Folder).
- Si no puede detectarlo, usa fallback `GITHUB_ORG`/`GITHUB_REPO` (modo clásico).
- Esto permite convivencia temporal de ambos modos durante la migración.

Recomendación operativa:

1. Ejecuta piloto con lock activo (`LOCK_SINGLE_REPO=true`).
2. Valida varios commits o PR merges a `qa` en ese repo.
3. Cambia a `LOCK_SINGLE_REPO=false` recién al entrar a Organization Folder multirepo.

### 3.8 Configurar webhooks externos (Solo Jenkins)

Aplica cuando Jenkins sea el orquestador CI/CD del proyecto.

GitHub (si usas Job Pipeline clásico por repo):

- Payload URL: `https://<jenkins-public-url>/github-webhook/`
- Content type: `application/json`
- Events: `Push` y `Pull requests`

GitHub (si usas Organization Folder):

- Recomendado: integración con GitHub App en Jenkins para manejo automático de webhooks por repositorio descubierto.
- Alternativa: webhook a nivel organización apuntando a `https://<jenkins-public-url>/github-webhook/`.
- Después de configurar credenciales/app, ejecutar `Scan Organization Now`.

Jira (System → WebHooks):

- URL: valor de `jira_webhook_url` (terraform output)
- Events: `Issue updated` (incluyendo cambio de status)

### 3.9 Ejecutar una prueba end-to-end (Según ruta elegida)

- Ruta Local: valida `terraform plan/apply` y revisa outputs.
- Ruta Jenkins: ejecuta pipeline y valida notificaciones/tickets.

1. Ejecuta el pipeline manualmente en Jenkins (sin parámetros) para validar Build/Test/Deploy QA.
2. Fuerza una falla en una rama de prueba para confirmar creación de ticket Jira y notificación FAIL a Teams.
3. Cambia el ticket a `Resolved`/`Done` para validar webhook Jira y notificación de resolución en Teams.

---

## 3.10 Setup con dos repositorios (Solo Jenkins)

Aplica cuando tienes un repo de plataforma (este proyecto) y un repo de aplicación separado.

### Rol de cada repo

| Repo | Qué contiene | Qué hace el pipeline |
|---|---|---|
| `devops-automation-platform` (repo 1) | Lambdas, Terraform, Jenkinsfile principal | Despliega Lambdas y infraestructura en AWS |
| Tu repo de app (repo 2) | Código de tu aplicación | Build/Test de la app y notifica usando las Lambdas del repo 1 |

### Paso 1 — Preparar el repo de app

1. Copia `jenkins/Jenkinsfile.app-template` de este repo al repo de tu app como `jenkins/Jenkinsfile`.
2. Edita las variables al inicio del archivo:
   - `APP_NAME`: nombre de tu aplicación.
   - `LAMBDA_NOTIFIER`: nombre exacto de la función `teams-notifier` en AWS.
   - `JIRA_PROJECT_KEY`: tu project key en Jira.
   - `AWS_REGION`: región donde desplegaste las Lambdas.
3. Personaliza los stages `Build` y `Test` según el stack de tu app (Node.js, Python, Java, etc.).
4. Commit y push de `jenkins/Jenkinsfile` al repo de app.

### Paso 2 — Crear el job en Jenkins para el repo de app

En Jenkins → New Item → `app-piloto-ci` → Pipeline → OK:

| Sección | Campo | Valor |
|---|---|---|
| General | GitHub project | ✅ activado |
| General | Project URL | `https://github.com/iMony-Tech/devops-automation-platform-test/` |
| Build Triggers | GitHub hook trigger | ✅ activado |
| Pipeline | Definition | `Pipeline script from SCM` |
| Pipeline | SCM | `Git` |
| Pipeline | Repository URL | `https://github.com/iMony-Tech/devops-automation-platform-test.git` |
| Pipeline | Credentials | `github-token` |
| Pipeline | Branch | `*/qa` (crear job adicional o multibranch para `prod`) |
| Pipeline | Script Path | `jenkins/Jenkinsfile` |

Las credenciales `jira-url`, `jira-api-token`, `teams-webhook` ya están configuradas en Jenkins — este job las reutiliza automáticamente por ID.

### Paso 3 — Agregar webhook en el repo de app

En GitHub → repo de app → Settings → Webhooks → Add webhook:

| Campo | Valor |
|---|---|
| Payload URL | `https://<jenkins-url>/github-webhook/` |
| Content type | `application/json` |
| Events | `Just the push event` |
| Active | ✅ |

### Flujo resultante

```
Repo 1 (devops-automation-platform)
    commit o PR merge a qa o prod  →  Job: devops-platform-deploy
                   →  Despliega Lambdas en AWS

Repo 2 (tu app)
    commit o PR merge a qa o prod  →  Job: app-piloto-ci
                   →  Build + Test de la app
                        │
                    Éxito → Lambda teams-notifier → Teams ✅
                    Fallo → Jira ticket + teams-notifier → Teams ❌
```

### 3.11 Flujo recomendado de 3 jobs Jenkins (nombres descriptivos)

Para que el flujo sea fácil de operar, usa estos 3 jobs con nombres explícitos:

| Orden | Nombre sugerido | Nombre actual típico | Trigger | Responsabilidad |
|---|---|---|---|---|
| 1 | `01-app-repo-trigger` | `app-repo-trigger` | SCM change en repo app | Detecta cambios en repo app y dispara el orquestador |
| 2 | `02-platform-ci-qa-orchestrator` | `app-pilot-ci` | Upstream (`01-app-repo-trigger`) o manual | Ejecuta `jenkins/Jenkinsfile`: build/test/deploy/notificaciones/Jira |
| 3 | `03-platform-infra-bootstrap` | `devops-platform-deploy` (o job dedicado) | Manual bajo demanda | Ejecuta pipeline con `APPLY_TERRAFORM=true` para crear/actualizar infraestructura |

Flujo operacional:

1. Un commit en repo app activa `01-app-repo-trigger`.
2. `01-app-repo-trigger` dispara `02-platform-ci-qa-orchestrator`.
3. `02-platform-ci-qa-orchestrator` corre CI/CD completo:
    - Si falla: crea/reutiliza ticket Jira + notifica Teams.
    - Si pasa: notifica Teams y puede cerrar ticket abierto más reciente del branch.
4. `03-platform-infra-bootstrap` solo se usa para cambios de infraestructura (no en cada commit).

Recomendación de operación:

- Usa `03-platform-infra-bootstrap` únicamente cuando cambie Terraform, IAM, API Gateway o nombres de Lambda.
- Mantén `02-platform-ci-qa-orchestrator` para el flujo diario de la app.
- No mezcles responsabilidades de infraestructura con validación diaria de app.

---

## 4) Uso del Pipeline

### Disparo automático (qa o prod)

Cada commit o PR merge en `qa` o `prod` dispara el pipeline automáticamente vía webhook de GitHub.

Política obligatoria de ramas de promoción:

- El pipeline solo acepta ejecuciones para ramas `qa` y `prod`.
- Si la rama objetivo no es `qa` ni `prod`, el pipeline se bloquea antes de Build/Deploy.
- Se valida si el commit viene de PR mergeado; si no, se permite continuar cuando el commit fue directo a `qa`/`prod`.
- En flujo con repo app (`RUN_APP_REPO_TESTS=true`), la validación se hace sobre el commit HEAD del repo app en la rama objetivo.

### Eventos que Teams puede recibir

| `event_type` | Cuándo se envía |
|---|---|
| `build_success` | Pipeline QA exitoso |
| `build_failure` | Cualquier stage falla (incluye link a ticket Jira) |
| `deployment_success` | Despliegue exitoso |
| `deployment_failure` | Despliegue fallido |
| `jira_resolved` | Ticket resuelto manualmente vía Lambda |
| *(desde Jira webhook)* | Ticket cambia a DONE/RESOLVED/CLOSED |

### 4.1 Comportamiento validado de Jira y deduplicación

Comportamiento implementado y validado:

1. En falla de pipeline:
    - Usa autenticación Basic (`email:api_token`) con cuenta técnica Jira.
    - Descubre automáticamente el `issueType` válido del proyecto Jira.
    - Reutiliza ticket si existe uno abierto con label `jenkins-failure-<commit_hash>`.
    - Si no existe, crea ticket con labels:
      - `jenkins`
      - `failed-build`
      - `jenkins-failure-<commit_hash>`
      - `jenkins-branch-<branch_normalizado>`

2. En éxito de pipeline:
    - Busca tickets abiertos del branch actual (`failed-build` + `jenkins-branch-<branch_normalizado>`).
    - Limita a `maxResults=1` para cerrar solo el más reciente del branch.
    - Agrega comentario de resolución automática (build, commit, autor, URL).
    - Transiciona a estado `Done` usando transición Jira válida.
    - Envía Teams con `Resuelto por` y `Tickets cerrados`.

3. Compatibilidad Jira Cloud:
    - Para búsquedas JQL se usa `/rest/api/3/search/jql` (no `/rest/api/3/search`, deprecado).
    - El campo `description` de Jira se envía en formato ADF (Atlassian Document Format).

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
| Lambda falla con env var missing | Secretos `TF_VAR_*` no cargados o credenciales Jenkins incompletas | Exportar `TF_VAR_*` localmente o revisar credentials en Jenkins y volver a aplicar |
| Jira webhook no llega a la Lambda | URL `jira_webhook_url` incorrecta | Ejecutar `terraform output jira_webhook_url` y actualizar en Jira |
| Ticket Jira no se crea en falla | Token Jira expirado o credencial mal configurada | Rotar el API Token y actualizar la credencial `jira-api-token` en Jenkins |
| Teams no recibe notificación | Webhook de Teams expirado | Regenerar el webhook en el canal Teams y actualizar credencial |
| Jenkins no puede crear rama | Token GitHub sin permisos `repo` | Regenerar token con scope `repo` y actualizar credencial `github-token` |

---

## 7) Mantenimiento de Documentación

- Actualizar **este archivo** para cambios operativos o de arquitectura.
- No crear archivos históricos de resumen.
- Mantener `docs/README.md` solo como índice.

---

## 8) Runbook Operativo Corto (día a día)

Usa este runbook como checklist rápido para operación diaria.

### 8.1 Inicio de jornada

1. Verificar estado Jenkins (jobs en verde, cola sin bloqueos).
2. Verificar credenciales vigentes en Jenkins:
    - `github-token`
    - `jira-url`
    - `jira-api-token`
    - `teams-webhook`
    - `teams-qa-webhook`
3. Verificar conectividad AWS/Lambdas:
    - `devops-platform-teams-notifier`
    - `devops-platform-jira-event-handler`

### 8.2 Si hay falla de pipeline

1. Confirmar que se creó o reutilizó ticket Jira.
2. Confirmar notificación Teams con:
    - número de ticket
    - resumen del ticket
    - link de Jira
3. Confirmar deduplicación:
    - para mismo commit (`jenkins-failure-<hash>`) no debe abrir otro ticket.

### 8.3 Si hay éxito después de una falla

1. Confirmar notificación Teams de build exitoso con:
    - `Resuelto por`
    - `Tickets cerrados`
2. Confirmar en Jira:
    - comentario automático de resolución en el ticket
    - transición a `Done` del ticket más reciente del branch

### 8.4 Si hay cambio de infraestructura

1. Ejecutar job de bootstrap infra con `APPLY_TERRAFORM=true`.
2. Validar outputs Terraform y endpoints API Gateway.
3. Ejecutar una corrida de validación (build controlado) para confirmar notificaciones.

---

## 9) Renombrado Seguro de los 3 Jobs Jenkins

Objetivo: adoptar nombres descriptivos sin romper triggers ni flujo actual.

Nombres objetivo:

1. `01-app-repo-trigger`
2. `02-platform-ci-qa-orchestrator`
3. `03-platform-infra-bootstrap`

### 9.1 Orden recomendado de cambio

1. Renombrar `app-repo-trigger` -> `01-app-repo-trigger`.
2. Actualizar configuración upstream/downstream para que dispare el nuevo nombre.
3. Renombrar `app-pilot-ci` -> `02-platform-ci-qa-orchestrator`.
4. Renombrar job de infraestructura a `03-platform-infra-bootstrap`.

### 9.2 Checklist para no romper el flujo

1. Revisar referencias de nombre de job en:
    - configuraciones upstream/downstream
    - notificaciones
    - scripts externos (si existen)
2. Ejecutar un build manual por job tras renombrar.
3. Ejecutar un trigger real desde SCM para validar encadenamiento.
4. Confirmar que el job 2 sigue obteniendo `jenkins/Jenkinsfile` desde la rama objetivo (`qa`/`prod`).

Nota sobre políticas de ramas en GitHub:

- Si tu organización restringe la creación de ramas protegidas (`qa`/`prod`), el credencial `github-token` de Jenkins debe tener permisos de admin o bypass de reglas.
- El flujo oficial es: commits o PR merges en `qa`/`prod`; Jenkins ya no crea ramas de trabajo.
- Si se requiere automatizar creación de ramas en el futuro, debe implementarse en un job separado y no en el pipeline de promoción a QA.

### 9.3 Criterio de aceptación del renombrado

1. Un push al repo app dispara `01-app-repo-trigger`.
2. `01-app-repo-trigger` dispara `02-platform-ci-qa-orchestrator`.
3. El job 2 completa pipeline y notifica Teams.
4. El job 3 se ejecuta solo cuando se solicita infraestructura.

---

## 10) Validación End-to-End (evidencias)

Esta validación confirma el ciclo completo: falla controlada -> ticket Jira -> corrección -> cierre automático -> notificación final.

### 10.1 Escenario A: falla controlada

1. Introducir una falla temporal de pruebas en repo app.
2. Hacer push a `qa` o `prod`.
3. Evidencias esperadas en logs Jenkins:
    - `Pipeline FAILED - Error Handling`
    - `Using Jira issue type: ...`
    - `Jira ticket created: <KEY>` o `Reusing existing Jira ticket: <KEY>`
    - `Failure notification sent to Teams`
4. Evidencias esperadas en Teams:
    - mensaje de build fallido
    - ticket Jira visible con link

### 10.2 Escenario B: corrección

1. Quitar la falla temporal y hacer push.
2. Evidencias esperadas en logs Jenkins:
    - `Status: SUCCESS`
    - `Resolving Jira ticket: <KEY>`
    - `Ticket <KEY> transitioned to Done`
    - `Success notification sent to Teams`
3. Evidencias esperadas en Teams:
    - build exitoso
    - `Resuelto por: <usuario>`
    - `Tickets cerrados: <KEY>`

### 10.3 Verificación Jira posterior

1. El ticket tiene comentario de resolución automática con build/commit/autor.
2. El ticket quedó en categoría `Done`.
3. Si vuelves a fallar con otro commit, se crea/reutiliza ticket correcto sin duplicados para el mismo hash.