# Arquitectura de la Plataforma DevOps

## Introducción

Este documento describe la arquitectura de la plataforma de automatización DevOps implementada en este repositorio.

La solución automatiza el flujo completo de integración continua, despliegue a entornos de prueba, gestión de incidentes y notificaciones al equipo.

La arquitectura integra diferentes herramientas del ecosistema DevOps para crear un flujo automatizado y reproducible.

---

# Componentes de la arquitectura

La plataforma está compuesta por los siguientes componentes:

### CI/CD

* Jenkins
  Motor de automatización que ejecuta los pipelines de CI/CD.

* GitHub
  Repositorio de código y gestión del flujo de Pull Requests.

---

### Automatización y eventos

* AWS Lambda
  Procesamiento de eventos y envío de notificaciones.

---

### Gestión de incidentes

* Jira
  Sistema de gestión de incidencias cuando un despliegue falla.

---

### Notificaciones

* Microsoft Teams
  Canal de comunicación para notificaciones automáticas.

---

# Flujo de CI/CD

El flujo de trabajo automatizado es el siguiente.

1. Jenkins crea una nueva rama en GitHub.
2. El desarrollador trabaja en la rama creada.
3. El desarrollador crea un Pull Request hacia la rama `develop`.
4. El Pull Request es revisado y se realiza el merge a `develop`.
5. GitHub envía un webhook a Jenkins.
6. Jenkins ejecuta el pipeline de CI/CD.

El pipeline ejecuta las siguientes etapas:

* Build
* Test
* Deploy a QA

---

# Flujo de despliegue

## Despliegue exitoso

Si el despliegue a QA se completa correctamente:

1. Jenkins finaliza el pipeline.
2. Jenkins invoca una función AWS Lambda.
3. Lambda envía una notificación al canal de Microsoft Teams indicando que el despliegue fue exitoso.

---

## Despliegue fallido

Si el despliegue falla durante el pipeline:

1. Jenkins detecta el error.
2. Jenkins crea automáticamente un ticket en Jira.
3. Se invoca una función AWS Lambda.
4. Lambda envía una notificación al canal de Teams informando que el despliegue falló.

La notificación incluye información relevante como:

* proyecto afectado
* etapa del pipeline que falló
* enlace al pipeline
* identificador del ticket de Jira

---

# Flujo de resolución de incidentes

Cuando el equipo corrige el problema:

1. El ticket de Jira se actualiza a estado **RESUELTO**.
2. Jira envía un webhook.
3. El webhook invoca una función AWS Lambda.
4. Lambda envía una notificación al canal de Teams indicando:

* el ticket que fue resuelto
* la persona que resolvió el incidente
* confirmación de que el problema fue atendido

---

# Arquitectura de infraestructura

La infraestructura se despliega utilizando **Terraform** como herramienta de Infrastructure as Code.

Los principales componentes desplegados en AWS son:

* funciones AWS Lambda
* API Gateway para webhooks
* roles y permisos IAM
* logs en CloudWatch

La plataforma está diseñada para integrarse con una **VPC existente** dentro de AWS.

---

# Estructura del repositorio

La estructura del proyecto está organizada para separar infraestructura, automatización y documentación.

```
terraform/        Infraestructura como código
modules/          Módulos reutilizables
lambda/           Funciones AWS Lambda
jenkins/          Definiciones de pipelines
scripts/          Scripts auxiliares
docs/             Documentación técnica
```

---

# Seguridad

La arquitectura sigue las siguientes prácticas de seguridad:

* Uso de roles IAM con privilegios mínimos.
* Gestión de secretos mediante variables seguras.
* Restricción de accesos mediante Security Groups.
* Integración segura con servicios externos.

---

# Escalabilidad

La arquitectura permite escalar fácilmente mediante:

* uso de funciones serverless
* modularización de Terraform
* separación de responsabilidades en los pipelines

---

# Mejoras futuras

Posibles mejoras para la plataforma:

* integración con AWS CodePipeline
* despliegue automático de entornos
* estrategias de rollback automático
* monitoreo avanzado y observabilidad
* integración con herramientas de seguridad DevSecOps

---

# Conclusión

Esta plataforma proporciona un flujo automatizado que permite mejorar la eficiencia del desarrollo, reducir tiempos de despliegue y mejorar la gestión de incidentes dentro del ciclo de vida del software.
