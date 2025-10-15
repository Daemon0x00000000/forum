#!/bin/bash
# Script de nettoyage complet de l'infrastructure forum-anonyme
# Usage: ./cleanup.sh [--profile wazabi] [--region eu-central-1]

set -e

PROFILE="${1:-wazabi}"
REGION="${2:-eu-central-1}"
APP_NAME="forum-anonyme"

echo "🧹 Nettoyage de l'infrastructure ${APP_NAME}"
echo "Profile AWS: ${PROFILE}"
echo "Région: ${REGION}"
echo ""

# Fonction pour exécuter des commandes AWS
aws_cmd() {
  aws --profile "${PROFILE}" --region "${REGION}" "$@"
}

echo "⏸️  Étape 1/10: Arrêt des services ECS..."
for service in "${APP_NAME}-api" "${APP_NAME}-thread" "${APP_NAME}-sender" "${APP_NAME}-mongodb"; do
  if aws_cmd ecs describe-services --cluster "${APP_NAME}-cluster" --services "${service}" &>/dev/null; then
    echo "  → Mise à l'échelle de ${service} à 0 tasks..."
    aws_cmd ecs update-service --cluster "${APP_NAME}-cluster" --service "${service}" --desired-count 0 || true
  fi
done

echo "⏳ Attente de l'arrêt des tasks (30 secondes)..."
sleep 30

echo "🗑️  Étape 2/10: Suppression des services ECS..."
for service in "${APP_NAME}-api" "${APP_NAME}-thread" "${APP_NAME}-sender" "${APP_NAME}-mongodb"; do
  if aws_cmd ecs describe-services --cluster "${APP_NAME}-cluster" --services "${service}" &>/dev/null; then
    echo "  → Suppression du service ${service}..."
    aws_cmd ecs delete-service --cluster "${APP_NAME}-cluster" --service "${service}" --force || true
  fi
done

echo "⏳ Attente de la suppression des services (20 secondes)..."
sleep 20

echo "🗑️  Étape 3/10: Suppression du cluster ECS..."
aws_cmd ecs delete-cluster --cluster "${APP_NAME}-cluster" || true

echo "🗑️  Étape 4/10: Suppression des task definitions..."
for family in "${APP_NAME}-api" "${APP_NAME}-thread" "${APP_NAME}-sender" "${APP_NAME}-mongodb"; do
  echo "  → Désactivation des task definitions ${family}..."
  task_defs=$(aws_cmd ecs list-task-definitions --family-prefix "${family}" --query 'taskDefinitionArns[]' --output text || true)
  for task_def in ${task_defs}; do
    aws_cmd ecs deregister-task-definition --task-definition "${task_def}" || true
  done
done

echo "🗑️  Étape 5/10: Suppression des Load Balancers..."
alb_arn=$(aws_cmd elbv2 describe-load-balancers --names "${APP_NAME}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ -n "${alb_arn}" ] && [ "${alb_arn}" != "None" ]; then
  echo "  → Suppression de l'ALB ${APP_NAME}-alb..."
  aws_cmd elbv2 delete-load-balancer --load-balancer-arn "${alb_arn}" || true
  echo "⏳ Attente de la suppression de l'ALB (30 secondes)..."
  sleep 30
fi

echo "🗑️  Étape 6/10: Suppression des Target Groups..."
for tg in "${APP_NAME}-thread-tg" "${APP_NAME}-sender-tg"; do
  tg_arn=$(aws_cmd elbv2 describe-target-groups --names "${tg}" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
  if [ -n "${tg_arn}" ] && [ "${tg_arn}" != "None" ]; then
    echo "  → Suppression du Target Group ${tg}..."
    aws_cmd elbv2 delete-target-group --target-group-arn "${tg_arn}" || true
  fi
done

echo "🗑️  Étape 7/10: Suppression du Service Discovery..."
namespace_id=$(aws_cmd servicediscovery list-namespaces --query "Namespaces[?Name=='${APP_NAME}.local'].Id" --output text 2>/dev/null || echo "")
if [ -n "${namespace_id}" ] && [ "${namespace_id}" != "None" ]; then
  echo "  → Récupération des services dans le namespace..."
  service_ids=$(aws_cmd servicediscovery list-services --filters Name=NAMESPACE_ID,Values="${namespace_id}" --query 'Services[].Id' --output text || true)
  for service_id in ${service_ids}; do
    echo "  → Suppression du service ${service_id}..."
    aws_cmd servicediscovery delete-service --id "${service_id}" || true
  done
  sleep 5
  echo "  → Suppression du namespace ${APP_NAME}.local..."
  aws_cmd servicediscovery delete-namespace --id "${namespace_id}" || true
fi

echo "🗑️  Étape 8/10: Suppression des CloudWatch Log Groups..."
for log_group in "/ecs/${APP_NAME}/api" "/ecs/${APP_NAME}/thread" "/ecs/${APP_NAME}/sender" "/ecs/${APP_NAME}/mongodb"; do
  if aws_cmd logs describe-log-groups --log-group-name-prefix "${log_group}" --query 'logGroups[0]' 2>/dev/null | grep -q "${log_group}"; then
    echo "  → Suppression du Log Group ${log_group}..."
    aws_cmd logs delete-log-group --log-group-name "${log_group}" || true
  fi
done

echo "🗑️  Étape 9/10: Suppression des Network Interfaces..."
echo "  → Recherche des ENIs orphelines..."
vpc_id=$(aws_cmd ec2 describe-vpcs --filters "Name=tag:Name,Values=${APP_NAME}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
if [ -n "${vpc_id}" ] && [ "${vpc_id}" != "None" ]; then
  eni_ids=$(aws_cmd ec2 describe-network-interfaces --filters "Name=vpc-id,Values=${vpc_id}" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text || true)
  for eni_id in ${eni_ids}; do
    echo "  → Suppression de l'ENI ${eni_id}..."
    aws_cmd ec2 delete-network-interface --network-interface-id "${eni_id}" || true
  done
fi

echo "🗑️  Étape 10/10: Suppression du VPC et ressources réseau..."
if [ -n "${vpc_id}" ] && [ "${vpc_id}" != "None" ]; then
  echo "  → Suppression des Security Groups..."
  sg_ids=$(aws_cmd ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=${APP_NAME}-*" --query 'SecurityGroups[].GroupId' --output text || true)
  for sg_id in ${sg_ids}; do
    aws_cmd ec2 delete-security-group --group-id "${sg_id}" 2>/dev/null || true
  done

  echo "  → Suppression des Subnets..."
  subnet_ids=$(aws_cmd ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc_id}" --query 'Subnets[].SubnetId' --output text || true)
  for subnet_id in ${subnet_ids}; do
    aws_cmd ec2 delete-subnet --subnet-id "${subnet_id}" || true
  done

  echo "  → Suppression des Route Tables..."
  rt_ids=$(aws_cmd ec2 describe-route-tables --filters "Name=vpc-id,Values=${vpc_id}" "Name=tag:Name,Values=${APP_NAME}-*" --query 'RouteTables[].RouteTableId' --output text || true)
  for rt_id in ${rt_ids}; do
    aws_cmd ec2 delete-route-table --route-table-id "${rt_id}" 2>/dev/null || true
  done

  echo "  → Suppression de l'Internet Gateway..."
  igw_id=$(aws_cmd ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${vpc_id}" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")
  if [ -n "${igw_id}" ] && [ "${igw_id}" != "None" ]; then
    aws_cmd ec2 detach-internet-gateway --internet-gateway-id "${igw_id}" --vpc-id "${vpc_id}" || true
    aws_cmd ec2 delete-internet-gateway --internet-gateway-id "${igw_id}" || true
  fi

  echo "  → Suppression du VPC ${vpc_id}..."
  aws_cmd ec2 delete-vpc --vpc-id "${vpc_id}" || true
fi

echo ""
echo "✅ Nettoyage terminé !"
echo ""
echo "📝 Note: Certaines ressources peuvent prendre quelques minutes à se supprimer complètement."
echo "   Vérifie la console AWS pour confirmer que tout a été supprimé."
