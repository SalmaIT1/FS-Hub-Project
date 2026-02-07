# FS Hub - Application Intelligente de Gestion d'Entreprise Informatique

## Description du Projet

FS Hub est une application intelligente de gestion complète pour société informatique, développée avec Flutter, intégrant le suivi des projets, des ressources humaines, des finances et la collaboration d'équipe. L'application utilise une approche DevOps et l'Intelligence Artificielle pour fournir une solution centralisée et automatisée.

## Objectifs Principaux

- **Centraliser** la gestion de tous les aspects de l'entreprise
- **Automatiser** les processus administratifs et opérationnels
- **Faciliter** la communication interne et la collaboration
- **Optimiser** la prise de décision grâce à l'analyse intelligente des données

## Fonctionnalités Principales

### 🚀 Gestion de Projets
- Suivi des projets informatiques avec estimation des dates de début et de fin
- Visualisation de l'avancement en temps réel
- Gestion des jalons et des livrables

### 📋 Gestion des Tâches
- Création et assignation des tâches aux employés
- Suivi de l'avancement et du temps passé
- Priorisation et dépendances entre tâches

### 👥 Gestion des Ressources Humaines
- Gestion des employés et des rôles
- Suivi des compétences et des disponibilités
- Planification des affectations

### 💰 Gestion Financière
- Gestion des salaires avec historique des paiements
- Suivi des revenus de la société
- Analyse des coûts par projet

### 🤝 Gestion Client
- Gestion des clients et des contacts
- Suivi des paiements et des crédits
- Historique des interactions

### 📄 Gestion Commerciale
- Création et suivi des devis
- Génération des factures
- Suivi des paiements clients

### 💬 Communication Interne
- Chat intégré pour l'équipe
- Partage de fichiers et de documents
- Canaux de discussion par projet

### 🔔 Système de Notifications
- Alertes sur les échéances des projets
- Notifications des paiements à effectuer
- Rappels des événements importants

## Architecture Technologique

### Frontend
- **Framework**: Flutter (multiplateforme)
- **Interface**: Moderne, ergonomique et responsive
- **Plateformes supportées**: iOS, Android, Web, Desktop
- **Services**: Authentification centralisée, API service, Stockage sécurisé

### Backend
- **Framework**: Dart Shelf (serveur REST API)
- **Authentification**: JWT avec gestion de sessions
- **Base de données**: MySQL avec schéma consolidé
- **Sécurité**: Tokens JWT, stockage sécurisé des mots de passe
- **Architecture**: Services centralisés avec contrats API alignés
- **API**: RESTful
- **Base de données**: MySQL 8.0
- **Authentification**: Sécurisée avec JWT

## Architecture du Système

### Contrats API Alignés
- **Endpoints**: /auth/, /demands/, /notifications/, /employees/, /email/
- **Format de réponse**: JSON standardisé avec succès/erreur
- **Codes HTTP**: 200 (succès), 401 (non autorisé), 404 (non trouvé), 500 (erreur serveur)
- **Headers**: Autorisation avec Bearer Token

### Flux Critiques Garantis
1. **Authentification**: Login → JWT → Profil utilisateur
2. **Système de Demandes**: Création → Traitement → Notification
3. **Notifications**: Temps réel → Persistance → Lecture/Non lecture
4. **CRUD**: Modèles cohérents → Validation → Gestion d'erreurs

### DevOps
- **Version control**: Git
- **Conteneurisation**: Docker
- **CI/CD**: Intégration et déploiement continus
- **Environnements**: Développement, test, production

### Intelligence Artificielle
- **Analyse prédictive**: Estimation des délais de projet
- **Détection des risques**: Prédiction des retards
- **Analyse comportementale**: Étude des habitudes de paiement clients
- **Tableaux de bord intelligents**: Aide à la décision

## 🐳 Dockerisation & Déploiement

### Prérequis
- Docker et Docker Compose installés
- Compte Docker Hub (optionnel pour le déploiement)

### Développement Local
```bash
# Démarrer tous les services
docker-compose up --build

# Accéder aux services :
# - Application : http://localhost
# - Backend API : http://localhost:8080
# - Base de données : localhost:3306
# - Adminer (gestion BDD) : http://localhost:8081
```

### Déploiement avec Docker
```bash
# Build des images
docker build -t fs-hub-backend ./backend
docker build -t fs-hub-frontend .

# Run avec Docker (sans docker-compose)
docker run -d -p 8080:8080 fs-hub-backend
docker run -d -p 80:80 fs-hub-frontend
```

## 🚀 CI/CD Pipeline

Le projet utilise GitHub Actions pour l'intégration et le déploiement continus :
- Tests automatiques à chaque push
- Build Docker automatique sur la branche main
- Déploiement automatique vers les environnements de production

## Ressources Disponibles

### Environnement de Développement
- ✅ Environnement Flutter configuré
- ✅ Langages et frameworks backend (API REST)
- ✅ Base de données MySQL
- ✅ Outils DevOps : Git, Docker, GitHub Actions

### Infrastructure
- ✅ Serveur de test
- ✅ Environnement de déploiement
- ✅ Outils de gestion de projet
- ✅ Données de test (clients, projets, paiements)

### Support
- ✅ Encadrement technique assuré
- ✅ Documentation complète
- ✅ Support continu
