# Arquitectura CI/CD - DevOps Platform

Este diagrama representa la arquitectura completa del flujo de integración continua y despliegue automático usando:

- GitHub
- Jenkins
- AWS Lambda
- Jira
- Microsoft Teams
- Ambiente QA

---

```mermaid
flowchart LR

%% ========================
%% GitHub
%% ========================

subgraph GITHUB["GitHub"]
A[Jenkins crea rama]
B[Developer trabaja en la rama]
C[Pull Request → develop]
D[Merge a develop]
E[GitHub Webhook]
end

%% ========================
%% Jenkins
%% ========================

subgraph JENKINS["Jenkins CI/CD"]
F[Jenkins Pipeline]
G[Build]
H[Test]
I[Deploy QA]
J{Deploy exitoso?}
end

%% ========================
%% QA ENVIRONMENT
%% ========================

subgraph QA["QA Environment"]
Q1[Aplicación desplegada]
end

%% ========================
%% AWS
%% ========================

subgraph AWS["AWS"]
L1[AWS Lambda\nNotificación]
end

%% ========================
%% JIRA
%% ========================

subgraph JIRA["Jira"]
M1[Crear Ticket automático]
M2[Equipo corrige error]
M3[Ticket RESUELTO]
M4[Jira Webhook]
end

%% ========================
%% TEAMS
%% ========================

subgraph TEAMS["Microsoft Teams"]
T1[Canal DevOps\nNotificación deploy exitoso]
T2[Canal DevOps\nNotificación de falla]
T3[Canal DevOps\nTicket atendido]
end

%% ========================
%% FLUJO
%% ========================

A --> B
B --> C
C --> D
D --> E

E --> F
F --> G
G --> H
H --> I

I --> Q1
I --> J

J -->|SI| L1
L1 --> T1

J -->|NO| M1
M1 --> L1
L1 --> T2

T2 --> M2
M2 --> M3
M3 --> M4

M4 --> L1
L1 --> T3