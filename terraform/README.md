# Terraform ECS Deployment

Infrastructure as Code pour déployer le forum anonyme sur AWS ECS Fargate.

## Architecture

- **VPC** avec 2 subnets publics
- **ECS Fargate** avec 4 services (MongoDB, API, Thread, Sender)
- **Application Load Balancer** pour Thread (port 81) et Sender (port 8090)
- **Service Discovery** pour communication interne entre services
- **CloudWatch Logs** pour les logs des conteneurs

## Prérequis

1. **AWS CLI configuré** avec le profil `wazabi`
   ```bash
   aws configure --profile wazabi
   ```

2. **Terraform installé** (version >= 1.0)
   ```bash
   brew install terraform  # macOS
   # ou télécharger depuis terraform.io
   ```

3. **Images Docker publiées** sur GitHub Container Registry
   - Les images doivent être disponibles sur `ghcr.io/daemon0x00000000/forum`
   - Assurez-vous que le CI/CD a poussé les images (lint → test → build-and-push)

## Déploiement

### 1. Initialiser Terraform

```bash
cd terraform
terraform init
```

### 2. Vérifier le plan

```bash
terraform plan \
  -var="github_repository=daemon0x00000000/forum" \
  -var="app_version=main" \
  -var="aws_profile=wazabi"
```

### 3. Déployer l'infrastructure

```bash
terraform apply \
  -var="github_repository=daemon0x00000000/forum" \
  -var="app_version=main" \
  -var="aws_profile=wazabi"
```

Ou en utilisant un tag/SHA spécifique :

```bash
terraform apply \
  -var="github_repository=daemon0x00000000/forum" \
  -var="app_version=abc1234" \
  -var="aws_profile=wazabi"
```

### 4. Récupérer les URLs

Après le déploiement, Terraform affichera les URLs :

```bash
terraform output thread_url   # URL pour voir les messages
terraform output sender_url   # URL pour envoyer des messages
```

## Mise à jour de l'application

Pour déployer une nouvelle version :

1. Push ton code sur GitHub (le CI/CD build les images)
2. Récupère le SHA du commit
3. Re-apply Terraform avec le nouveau SHA :

```bash
terraform apply \
  -var="app_version=<nouveau-sha>"
```

ECS fera un rolling update (blue-green) automatiquement.

## Variables disponibles

| Variable | Description | Défaut |
|----------|-------------|--------|
| `aws_region` | Région AWS | `eu-central-1` |
| `app_name` | Nom de l'application | `forum-anonyme` |
| `environment` | Environnement | `dev` |
| `github_repository` | Repo GitHub pour images | `daemon0x00000000/forum` |
| `app_version` | Version/tag/SHA des images | `main` |
| `vpc_cidr` | CIDR du VPC | `10.0.0.0/16` |

## Détruire l'infrastructure

⚠️ **Attention** : Cela supprime toutes les ressources et les données MongoDB !

```bash
terraform destroy
```

## Coûts estimés

- ECS Fargate (4 tasks) : ~25€/mois
- Application Load Balancer : ~20€/mois
- Data transfer : ~5€/mois
- **Total** : ~50€/mois

💡 Pour économiser, arrête les services ECS quand tu ne les utilises pas :
```bash
aws ecs update-service --cluster forum-anonyme-cluster \
  --service forum-anonyme-thread --desired-count 0 --profile wazabi
```

## Troubleshooting

### Les services ne démarrent pas

1. Vérifier les logs CloudWatch :
   ```bash
   aws logs tail /ecs/forum-anonyme/api --follow --profile wazabi
   ```

2. Vérifier que les images existent sur GHCR :
   - https://github.com/Daemon0x00000000/forum/pkgs/container/forum%2Fapi

### Erreur "No default VPC"

C'est normal, Terraform crée son propre VPC.

### Service Discovery ne fonctionne pas

Attends 1-2 minutes après le déploiement pour que DNS se propage.

## Architecture Blue-Green

Le déploiement rolling est configuré avec :
- `deployment_maximum_percent = 200` : Lance 2x les tasks pendant le déploiement
- `deployment_minimum_healthy_percent = 100` : Garde toujours 100% des tasks healthy

Flux :
1. Terraform met à jour la task definition
2. ECS lance les nouvelles tasks (2x total pendant transition)
3. Les nouvelles tasks passent les health checks
4. ECS route le traffic vers les nouvelles tasks
5. ECS termine les anciennes tasks
