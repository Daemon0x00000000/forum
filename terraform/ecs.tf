# ========================================
# IAM Roles for ECS
# ========================================

# Use existing ECS Task Execution Role ARN or reference
# If you don't have permission to create IAM roles, ask your admin for the ARN
# For now, we'll use the AWS managed execution role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# ========================================
# CloudWatch Log Groups
# ========================================

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.app_name}/api"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "thread" {
  name              = "/ecs/${var.app_name}/thread"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "sender" {
  name              = "/ecs/${var.app_name}/sender"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "mongodb" {
  name              = "/ecs/${var.app_name}/mongodb"
  retention_in_days = 7
}

# ========================================
# ECS Cluster
# ========================================

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# ========================================
# Service Discovery
# ========================================

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.app_name}.local"
  vpc         = aws_vpc.main.id
  description = "Service discovery namespace for ${var.app_name}"
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "db" {
  name = "db"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ========================================
# ECS Task Definitions
# ========================================

# MongoDB Task Definition
resource "aws_ecs_task_definition" "mongodb" {
  family                   = "${var.app_name}-mongodb"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "mongodb"
      image     = "mongo:latest"
      essential = true

      portMappings = [
        {
          containerPort = 27017
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.mongodb.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mongodb"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-mongodb-task"
  }
}

# API Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.app_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "ghcr.io/${lower(var.github_repository)}/api:${var.app_version}"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_URL"
          value = "mongodb://db.${var.app_name}.local:27017/forum"
        },
        {
          name  = "PORT"
          value = "3000"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/messages || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-api-task"
  }
}

# Thread Task Definition
resource "aws_ecs_task_definition" "thread" {
  family                   = "${var.app_name}-thread"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "thread"
      image     = "ghcr.io/${lower(var.github_repository)}/thread:${var.app_version}"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "API_URL"
          value = "http://api.${var.app_name}.local:3000"
        },
        {
          name  = "PORT"
          value = "80"
        },
        {
          name  = "SENDER_URL"
          value = "http://${aws_lb.main.dns_name}:8090"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.thread.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "thread"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-thread-task"
  }
}

# Sender Task Definition
resource "aws_ecs_task_definition" "sender" {
  family                   = "${var.app_name}-sender"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "sender"
      image     = "ghcr.io/${lower(var.github_repository)}/sender:${var.app_version}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "API_URL"
          value = "http://api.${var.app_name}.local:3000"
        },
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "THREAD_URL"
          value = "http://${aws_lb.main.dns_name}:81"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.sender.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "sender"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-sender-task"
  }
}

# ========================================
# ECS Services
# ========================================

# MongoDB Service
resource "aws_ecs_service" "mongodb" {
  name            = "${var.app_name}-mongodb"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.db.arn
  }

  tags = {
    Name = "${var.app_name}-mongodb-service"
  }
}

# API Service
resource "aws_ecs_service" "api" {
  name            = "${var.app_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api.arn
  }

  depends_on = [aws_ecs_service.mongodb]

  tags = {
    Name = "${var.app_name}-api-service"
  }
}

# Thread Service
resource "aws_ecs_service" "thread" {
  name            = "${var.app_name}-thread"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.thread.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.thread.arn
    container_name   = "thread"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.thread,
    aws_ecs_service.api
  ]

  tags = {
    Name = "${var.app_name}-thread-service"
  }
}

# Sender Service
resource "aws_ecs_service" "sender" {
  name            = "${var.app_name}-sender"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.sender.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sender.arn
    container_name   = "sender"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.sender,
    aws_ecs_service.api
  ]

  tags = {
    Name = "${var.app_name}-sender-service"
  }
}
