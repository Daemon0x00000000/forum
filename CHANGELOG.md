# [2.1.0](https://github.com/Daemon0x00000000/forum/compare/v2.0.0...v2.1.0) (2025-10-15)


### Bug Fixes

* update CodeQL Action to v3 and fix Snyk SARIF output ([3eda265](https://github.com/Daemon0x00000000/forum/commit/3eda2654c8690a280f811a285d20fccb042a2250))
* use continue-on-error instead of || true for Snyk SARIF generation ([559103c](https://github.com/Daemon0x00000000/forum/commit/559103c7f29af7817bbef811bd1ac46120457780))


### Features

* enhance CI/CD security with secrets scanning and SAST analysis; update version to 2.1.0 ([5bf06bd](https://github.com/Daemon0x00000000/forum/commit/5bf06bd5ffd2b44bfe5badb63d7cf78720f9abbe))



# Changelog

Tous les changements notables apportés à ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-10-15

### Ajouté
- **Pipeline de sécurité complète dans CI/CD**
  - **Secrets Scanning** avec Gitleaks pour détecter les secrets exposés
  - **Analyse SAST** avec Snyk pour identifier les vulnérabilités du code
  - Exécution en parallèle avant le linting
  - Upload automatique des résultats dans GitHub Security
  - Seuil de sévérité HIGH pour bloquer les vulnérabilités critiques
- **Documentation de sécurité** (`.github/SECURITY_SETUP.md`)
  - Guide de configuration Snyk
  - Instructions pour ajouter `SNYK_TOKEN`
  - Bonnes pratiques de sécurité
  - Commandes de test en local

### Sécurité
- **Détection automatique des secrets** : API keys, tokens, passwords hardcodés
- **Analyse des vulnérabilités** : Dépendances npm et code source
- **Intégration GitHub Security** : Alertes centralisées dans l'onglet Security
- **Permissions CI/CD renforcées** : Ajout de `security-events: write`

## [2.0.0] - 2025-10-15

### Ajouté
- **Infrastructure Terraform ECS complète** pour déploiement sur AWS Fargate
  - VPC avec 2 subnets publics dans eu-central-1 (Francfort)
  - ECS Cluster avec 4 services (MongoDB, API, Thread, Sender)
  - Application Load Balancer avec listeners sur ports 81 et 8090
  - Service Discovery pour communication interne entre services
  - CloudWatch Log Groups avec rétention de 7 jours
  - Healthchecks ECS pour API, Thread et Sender
  - Utilisation du rôle IAM existant `ecsTaskExecutionRole`
  - Rolling deployment (Blue-Green natif ECS)
  - URLs dynamiques depuis load balancer (plus de localhost hardcodé)
- **Pipeline CI/CD complète avec déploiement automatique**
  - Lint → Test → Build & Push vers GHCR
  - **Déploiement automatique** sur AWS ECS après build sur `main`
  - **Destruction manuelle** via workflow_dispatch
  - Affichage des URLs de déploiement après chaque déploiement
  - Release automatique du changelog
  - Terraform Cloud pour remote state management
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
- Script de cleanup AWS (`cleanup.sh`) pour supprimer toutes les ressources
- Migration vers nouvelle remote GitHub (`daemon0x00000000/forum`)
- Profil AWS `wazabi` configuré pour Terraform

### Modifié
- **Optimisation des permissions IAM**
  - Utilisation du rôle IAM existant au lieu de création dynamique
  - Suppression de toutes les dépendances à `iam:CreateRole`
  - Ajout de permissions granulaires (DescribeListenerAttributes, etc.)
  - Réduction des permissions requises (pas de création de rôles)
- **Suppression des tags sur ressources à permissions limitées**
  - CloudWatch Log Groups sans tags (évite `logs:TagResource`)
  - Service Discovery sans tags (évite `servicediscovery:TagResource`)
  - Simplification de la configuration pour environnements avec permissions limitées
- **Configuration CI/CD optimisée**
  - Suppression des credentials AWS de GitHub Actions
  - Utilisation de Terraform Cloud pour l'exécution
  - Variable `app_version` gérée dans Terraform Cloud
  - Format multiline EOF pour les outputs GitHub Actions
- **Images Docker**
  - Hébergées sur GitHub Container Registry (ghcr.io)
  - Références en minuscules pour compatibilité GHCR
  - Tags basés sur SHA de commit
- Services Thread et Sender utilisent des URLs dynamiques depuis variables d'environnement
- Tests API améliorés avec vérification des propriétés MongoDB
- Tests frontend améliorés avec validation de contenu HTML
- Healthcheck API corrigé pour utiliser `/api/messages` au lieu de `/messages`

### Supprimé
- Ancien Terraform EC2 avec user_data script
- Création dynamique de rôles IAM (utilisation de rôles existants)
- Tags sur CloudWatch Log Groups et Service Discovery
- Dépendances aux permissions IAM avancées
- URLs localhost hardcodées dans les templates EJS

### Sécurité
- **Permissions minimales** : Politique IAM avec principe du moindre privilège
- **Rôle IAM réutilisable** : Un seul rôle `ecsTaskExecutionRole` pour tous les projets
- **Pas de création de rôles** : Évite les permissions sensibles `iam:CreateRole`
- **Credentials centralisés** : AWS credentials dans Terraform Cloud uniquement

### Technique
- **ECS Fargate** au lieu de EC2 (meilleure scalabilité, pas de gestion serveur)
- **Service Discovery** avec DNS privé (*.forum-anonyme.local)
- **Rolling deployment** natif ECS:
  - `deployment_maximum_percent = 200` (lance 2x les tasks)
  - `deployment_minimum_healthy_percent = 100` (garde 100% healthy)
- **CI/CD automatisée** avec Terraform Cloud dans GitHub Actions
- **Terraform Cloud** pour state management et remote execution
- **Coût estimé**: ~50€/mois (vs ~105€ avec l'ancienne architecture)

### Documentation
- Guide IAM complet pour résoudre les erreurs de permissions
- Instructions pour créer le rôle ECS Task Execution
- Policy IAM prête à l'emploi avec permissions minimales
- Guide de dépannage pour les erreurs communes
- Configuration Terraform Cloud dans `.github/workflows/ci-cd.yml`

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
