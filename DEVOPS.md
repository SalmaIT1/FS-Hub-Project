# 🚀 FS-Hub DevOps & Automation Strategy

Ce document détaille l'infrastructure DevOps mise en place pour assurer la gestion des versions, l'intégration continue (CI) et le déploiement continu (CD) de l'écosystème FS-Hub.

## 🛠 Architecture DevOps

La stack DevOps repose sur les piliers suivants :
- **Gestion de version** : Git & GitHub.
- **CI/CD Pipeline** : GitHub Actions.
- **Conteneurisation** : Docker & Docker Compose.
- **Registre d'images** : Docker Hub.
- **Hébergement** : Render (Backend & Frontend Web).

---

## 🔄 Pipeline CI/CD (`.github/workflows/ci-cd.yml`)

Le pipeline est déclenché à chaque `push` sur les branches `main` et `develop`, ainsi que sur les `pull requests`.

### 1. Intégration Continue (CI)
- **Analyse Statique** : Vérification de la qualité du code avec `flutter analyze` et `dart analyze`.
- **Tests Automatisés** : Exécution des suites de tests unitaires et d'intégration pour le frontend et le backend.
- **Caching** : Utilisation de caches pour les dépendances Flutter/Dart et les couches Docker afin d'accélérer les builds de ~50%.

### 2. Livraison Continue (CD)
- **Build Docker** : Création d'images multi-étapes optimisées pour la production.
- **Versionnement des Images** : Les images sont tagguées avec :
  - `latest` : Dernière version stable.
  - `sha-xxxx` : Version spécifique au commit pour permettre les rollbacks.
  - `v*` : Tags de version sémantique (ex: `v1.0.2`).
- **Push Registre** : Envoi automatique sur Docker Hub (`salmait1/fs-hub-*`).

### 3. Déploiement Automatisé
- **Production** : Déclenchement automatique d'un déploiement sur Render via un Webhook dès que les nouvelles images sont prêtes.

---

## 📦 Gestion des Versions

Nous suivons le modèle **GitFlow** simplifié :
- `main` : Code stable prêt pour la production.
- `develop` : Intégration des nouvelles fonctionnalités.
- `feature/*` : Développement de fonctionnalités isolées.

Les versions sont marquées par des **Tags Git** (ex: `git tag v1.0.0`), ce qui déclenche automatiquement un build de production taggué.

---

## 🐳 Environnements Docker

### Développement (`docker-compose.yml`)
Permet de lancer localement toute la stack (Backend, Frontend, DB, Redis, AI Service) avec un rechargement automatique.

### Production (`Dockerfile`)
- **Frontend** : Build Flutter Web servi par un serveur **Nginx** optimisé (compression, cache headers).
- **Backend** : Exécutable Dart natif tournant sur une image **Alpine Linux** minimale pour une sécurité maximale et une empreinte mémoire réduite.

---

## 🛡 Sécurité et Monitoring
- **Secrets** : Toutes les clés d'API et identifiants sont gérés via les *GitHub Actions Secrets*.
- **Non-root User** : Le backend tourne sous un utilisateur non-privilégié dans le conteneur.
- **Analyse de vulnérabilités** : Intégrée au processus de build Docker.

---

## 📝 Commandes Utiles

### Développement local — une seule commande (Windows)

Lance **ai-service**, **backend**, **ngrok** (tunnel HTTPS vers le port 8080) et **Flutter** sur l’appareil connecté :

```powershell
# Depuis la racine du projet
.\dev.ps1 -StopFirst

# Téléphone précis + libération des ports
.\dev.ps1 -Device D6NRSGV4IVAMIJTC -StopFirst

# Émulateur Android (sans ngrok, API = 10.0.2.2)
.\dev.ps1 -Emulator

# Services seulement (pas Flutter) — utile si l’app tourne déjà
.\dev.ps1 -ServicesOnly
```

Arrêter backend / IA / ngrok :

```powershell
.\scripts\stop-dev.ps1
```

Prérequis : `dart`, `flutter`, `ngrok`, `python` (+ `pip install -r ai-service/requirements.txt` une fois). MySQL local doit tourner (voir `backend/.env`).

Logs : dossier `.dev/logs/`. URL ngrok enregistrée dans `.dev/ngrok-url.txt`.

### Lancer l'environnement complet en Docker
```bash
docker-compose up --build
```

### Créer une nouvelle version
```bash
git tag v1.1.0
git push origin v1.1.0
```
