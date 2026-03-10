# Plataforma de Automatización DevOps

Este repositorio contiene la **infraestructura como código (IaC)** y los componentes de automatización necesarios para implementar un flujo completo de **CI/CD**, despliegue a entornos de prueba (QA), gestión automática de incidentes y notificaciones al equipo.

La plataforma integra diferentes herramientas del ecosistema DevOps para automatizar el ciclo de desarrollo desde la creación de ramas hasta la resolución de incidentes.

---

# Tecnologías utilizadas

La plataforma integra las siguientes herramientas:

* Jenkins – Orquestación de pipelines CI/CD
* GitHub – Control de versiones y gestión de Pull Requests
* Terraform – Infraestructura como código
* AWS Lambda – Procesamiento de eventos y notificaciones
* Jira – Gestión de incidentes
* Microsoft Teams – Notificaciones al equipo

---

# Arquitectura de la solución

La arquitectura automatiza el flujo completo de desarrollo, integración, despliegue y gestión de incidentes.

Principales capacidades:

* Creación automática de ramas desde Jenkins
* Flujo de Pull Request hacia la rama `develop`
* Ejecución automática de pipelines
* Despliegue automático al entorno QA
* Creación automática de tickets cuando falla un despliegue
* Notificaciones automáticas al equipo de desarrollo
* Notificación cuando un incidente es resuelto

---

# Flujo de CI/CD

El flujo de trabajo implementado es el siguiente:

1. Jenkins crea una rama en GitHub
2. El desarrollador trabaja sobre esa rama
3. El desarrollador crea un Pull Request hacia `develop`
4. Se realiza el merge a `develop`
5. GitHub envía un webhook a Jenkins
6. Jenkins ejecuta el pipeline de CI/CD

El pipeline ejecuta las siguientes etapas:

* Build
* Test
* Deploy a QA

---

# Resultado del pipeline

## Despliegue exitoso

Si el despliegue a QA es exitoso:

1. Jenkins finaliza el pipeline
2. Se invoca una función AWS Lambda
3. Lambda envía una notificación al canal de Microsoft Teams indicando que el despliegue fue exitoso.

---

## Despliegue fallido

Si el despliegue falla:

1. Jenkins detecta el error en el pipeline
2. Jenkins crea automáticamente un ticket en Jira
3. AWS Lambda envía una notificación al canal de Teams informando que el despliegue falló

La notificación incluye información relevante como:

* Nombre del proyecto
* Etapa que falló
* Enlace al pipeline
* Identificador del ticket creado en Jira

---

# Resolución de incidentes

Cuando el equipo corrige el problema:

1. El ticket de Jira se marca como **RESUELTO**
2. Jira envía un webhook
3. El webhook invoca una función AWS Lambda
4. Lambda envía una notificación a Microsoft Teams indicando:

* El ticket que fue resuelto
* La persona que resolvió el incidente
* Confirmación de que el problema fue atendido

---

# Estructura del repositorio

El repositorio está organizado de la siguiente forma:

```
terraform/        Infraestructura como código
modules/          Módulos reutilizables de Terraform
lambda/           Funciones AWS Lambda
jenkins/          Definiciones de pipelines Jenkins
scripts/          Scripts de automatización
docs/             Documentación de arquitectura
```

Descripción de cada componente:

terraform
Contiene la infraestructura necesaria para desplegar los componentes en AWS.

modules
Módulos reutilizables que permiten mantener la infraestructura organizada.

lambda
Código de las funciones AWS Lambda utilizadas para procesar eventos y enviar notificaciones.

jenkins
Definición de pipelines CI/CD utilizados por Jenkins.

scripts
Scripts auxiliares utilizados por el pipeline.

docs
Documentación técnica y diagramas de arquitectura.

---

# Infraestructura como Código

Toda la infraestructura se gestiona mediante Terraform.

Los componentes principales que se despliegan son:

* Funciones AWS Lambda
* API Gateway para recibir webhooks
* Roles y permisos IAM
* Logs en CloudWatch

La arquitectura está diseñada para integrarse con una **VPC existente en AWS**.

---

# Integraciones del sistema

La plataforma se integra con los siguientes sistemas:

GitHub
Gestión del código fuente y flujo de Pull Requests.

Jenkins
Orquestación del pipeline CI/CD y ejecución de despliegues.

Jira
Gestión automática de incidentes cuando falla un despliegue.

AWS Lambda
Procesamiento de eventos y envío de notificaciones.

Microsoft Teams
Recepción de notificaciones relacionadas con despliegues e incidentes.

---

# Despliegue de la infraestructura

Para desplegar la infraestructura se utilizan los siguientes comandos.

Inicializar Terraform:

```
terraform init
```

Planificar la infraestructura:

```
terraform plan
```

Aplicar la infraestructura:

```
terraform apply
```

---

# Mejoras futuras

Posibles mejoras para la plataforma:

* Integración con AWS CodePipeline
* Automatización completa de entornos
* Estrategias de rollback automático
* Observabilidad y monitoreo
* Notificaciones avanzadas en Teams
* Automatización del ciclo completo de incidentes

---

# Autor

Alberto Juan Gabino
