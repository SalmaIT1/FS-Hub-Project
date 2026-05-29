# Mémoire / thèse — diagrammes FS-Hub (`docs/uml/thesis/`)

Ensemble **aligné sur le code** (montages `backend/bin/server.dart`, routes `*_routes.dart`).

## Paquetage / domaine / navigation

| Fichier | Rôle |
|---------|------|
| `00-deployment.puml` | Déploiement 3-tiers |
| `01-package-backend.puml` | Clean arch. backend |
| `01-package-frontend.puml` (+ page1/page2) | Couches Flutter |
| `02-class-domain.puml` | Objets domaine unifiés |
| `nav-flutter-routes.puml` | Routage + garde permissions |

## Cas d’utilisation (sprints)

`uc-sprint01-auth.puml` … `uc-sprint07-collab.puml` (+ RH sprint 3–4).

## Séquences « originales » mémoire

| Fichier | Flux |
|---------|------|
| `seq-auth-jwt-rbac.puml` | Login JWT + RBAC RH |
| `seq-rh-leave.puml` | Congés |
| `seq-projects-tasks.puml` | Projets / tâches |
| `seq-finance-invoice.puml` | Facturation |
| `seq-collab-websocket.puml` | Temps réel |

## Séquences complémentaires — **acteurs mélangés** (`seq-mix-*`)

| Fichier | Acteurs principaux |
|---------|-------------------|
| `seq-mix-auth-forgot-reset.puml` | Utilisateur + SMTP (`EmailService`) |
| `seq-mix-employees-catalog.puml` | Employé auto-profil + RH |
| `seq-mix-demands.puml` | Demandeur + superviseur |
| `seq-mix-tasks-progress.puml` | Chef projet + exécutant |
| `seq-mix-projects-members.puml` | Chef + collaborateur ajouté |
| `seq-mix-finance-quote-approve.puml` | Commercial + client |
| `seq-mix-finance-payment.puml` | Comptable + idempotency |
| `seq-mix-credits-apply.puml` | Auditeur + comptable |
| `seq-mix-uploads-chat.puml` | Expéditeur + destinataire |
| `seq-mix-ai-risks.puml` | Manager BI + service Python |

## Activités « originales »

| Fichier |
|---------|
| `act-rh-leave.puml` |
| `act-finance-invoice.puml` |
| `act-collab-notify.puml` |

## Activités complémentaires (`act-mix-*`)

Même thématique que `seq-mix-*` (un couple par scénario métier).

## Rendu

Extension PlantUML / CLI : `plantuml docs/uml/thesis/*.puml`
