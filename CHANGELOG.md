# 1.0.0 (2025-10-15)



# Changelog

Tous les changements notables apportés à ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-15

### Ajouté
- **Infrastructure Terraform ECS complète** pour déploiement sur AWS Fargate
  - VPC avec 2 subnets publics dans eu-central-1 (Francfort)
  - ECS Cluster avec 4 services (MongoDB, API, Thread, Sender)
  - Application Load Balancer avec listeners sur ports 81 et 8090
  - Service Discovery pour communication interne entre services
  - CloudWatch Log Groups avec rétention de 7 jours
  - Utilisation du rôle IAM existant `ecsTaskExecutionRole`
  - Rolling deployment (Blue-Green natif ECS)
  - Documentation complète dans `terraform/README.md`
- **Pipeline CI/CD complète avec déploiement automatique**
  - Lint → Test → Build & Push vers GHCR
  - **Déploiement automatique** sur AWS ECS après build sur `main`
  - **Destruction manuelle** via workflow_dispatch
  - Affichage des URLs de déploiement après chaque déploiement
  - Release automatique du changelog
- **Documentation IAM** pour configuration des permissions
  - `terraform/IAM_POLICY.json` - Policy IAM complète pour déploiement
  - `terraform/SETUP_IAM.md` - Guide de configuration IAM pas-à-pas
  - Instructions pour créer le rôle `ecsTaskExecutionRole`
- **CLAUDE.md** - Documentation complète du projet pour Claude Code
  - Architecture détaillée des 4 services
  - Commandes de développement et déploiement
  - Guide des tests et bonnes pratiques
  - Instructions Terraform ECS et CI/CD
- **Tests améliorés** - 26 tests au total (11 API + 6 Thread + 9 Sender)
  - Tests de validation des champs requis (username, content)
  - Tests de vérification des timestamps et IDs MongoDB
  - Tests d'ordre des messages (décroissant par date)
  - Tests de gestion d'erreurs (404, champs vides)
  - Tests de rendu des templates EJS
  - Tests de trim des espaces dans les champs
- Migration vers nouvelle remote GitHub (`daemon0x00000000/forum`)
- Profil AWS `wazabi` configuré pour Terraform

### Modifié
- **Optimisation des permissions IAM**
  - Utilisation du rôle IAM existant au lieu de création dynamique
  - Suppression de toutes les dépendances à `iam:CreateRole`
  - Réduction des permissions requises (pas de création de rôles)
- **Suppression des tags sur ressources à permissions limitées**
  - CloudWatch Log Groups sans tags (évite `logs:TagResource`)
  - Service Discovery sans tags (évite `servicediscovery:TagResource`)
  - Simplification de la configuration pour environnements avec permissions limitées
- Images Docker hébergées sur GitHub Container Registry (ghcr.io)
- Tests API améliorés avec vérification des propriétés MongoDB
- Tests frontend améliorés avec validation de contenu HTML

### Supprimé
- Ancien Terraform EC2 avec user_data script
- Création dynamique de rôles IAM (utilisation de rôles existants)
- Tags sur CloudWatch Log Groups et Service Discovery
- Dépendances aux permissions IAM avancées

### Sécurité
- **Permissions minimales** : Politique IAM avec principe du moindre privilège
- **Rôle IAM réutilisable** : Un seul rôle `ecsTaskExecutionRole` pour tous les projets
- **Pas de création de rôles** : Évite les permissions sensibles `iam:CreateRole`

### Technique
- **ECS Fargate** au lieu de EC2 (meilleure scalabilité, pas de gestion serveur)
- **Service Discovery** avec DNS privé (*.forum-anonyme.local)
- **Rolling deployment** natif ECS:
  - `deployment_maximum_percent = 200` (lance 2x les tasks)
  - `deployment_minimum_healthy_percent = 100` (garde 100% healthy)
- **CI/CD automatisée** avec Terraform dans GitHub Actions
- **Coût estimé**: ~50€/mois (vs ~105€ avec l'ancienne architecture)

### Documentation
- Guide IAM complet pour résoudre les erreurs de permissions
- Instructions pour créer le rôle ECS Task Execution
- Policy IAM prête à l'emploi avec permissions minimales
- Guide de dépannage pour les erreurs communes

## [1.1.0] - 2023-09-15

### Ajouté
- Tests automatisés pour l'API, Thread et Sender
- Configuration MongoDB Memory Server pour les tests
- Mode test pour éviter les appels API réels lors des tests

### Corrigé
- Correction des problèmes de connexion à la base de données
- Ajout des permissions de CI/CD pour la mise à jour automatique du changelog

## [1.0.0] - 2023-09-01

### Ajouté
- Architecture microservices avec quatre services: API, DB, Thread, Sender
- Configuration Docker et Docker Compose
- Système de forum anonyme avec pseudonymes
- Pipeline CI/CD complète
- Tests automatisés
- Gestion des versions avec Conventional Commits
- Génération automatique des changelogs 