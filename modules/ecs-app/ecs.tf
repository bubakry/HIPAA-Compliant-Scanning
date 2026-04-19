resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${local.name_prefix}/fastapi"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.app.name
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cluster"
    },
  )
}

resource "aws_lb" "app" {
  count = local.service_enabled ? 1 : 0

  name                             = substr("${local.sanitized_project}-${var.environment}-alb", 0, 32)
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.alb[0].id]
  subnets                          = var.public_subnet_ids
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.production_safeguards
  drop_invalid_header_fields       = true
  idle_timeout                     = 60

  access_logs {
    bucket  = var.alb_logs_bucket_name
    prefix  = "alb-access"
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    },
  )
}

resource "aws_lb_target_group" "app" {
  count = local.service_enabled ? 1 : 0

  name                 = substr("${local.sanitized_project}-${var.environment}-tg", 0, 32)
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    matcher             = "200"
    path                = "/health/live"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-tg"
    },
  )
}

resource "aws_lb_listener" "https" {
  count = local.service_enabled ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}

resource "aws_ecs_task_definition" "app" {
  count = local.service_enabled ? 1 : 0

  family                   = "${local.name_prefix}-fastapi"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(
    [
      {
        name      = "fastapi"
        image     = var.container_image
        essential = true
        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = var.container_port
            protocol      = "tcp"
          }
        ]
        environment = [
          {
            name  = "APP_DATA_BUCKET"
            value = var.app_data_bucket_name
          },
          {
            name  = "AWS_REGION"
            value = var.aws_region
          },
          {
            name  = "DATABASE_HOST"
            value = var.db_endpoint
          },
          {
            name  = "DATABASE_NAME"
            value = var.db_name
          },
          {
            name  = "DATABASE_PORT"
            value = tostring(var.db_port)
          },
          {
            name  = "LOG_LEVEL"
            value = "INFO"
          },
          {
            name  = "SERVICE_NAME"
            value = local.name_prefix
          }
        ]
        secrets = [
          {
            name      = "DB_SECRET_JSON"
            valueFrom = var.db_secret_arn
          }
        ]
        healthCheck = {
          command = [
            "CMD-SHELL",
            "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health/live').read()\" || exit 1",
          ]
          interval    = 30
          retries     = 3
          startPeriod = 20
          timeout     = 5
        }
        linuxParameters = {
          initProcessEnabled = true
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.app.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "fastapi"
          }
        }
        readonlyRootFilesystem = true
      }
    ]
  )

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-task"
    },
  )
}

resource "aws_ecs_service" "app" {
  count = local.service_enabled ? 1 : 0

  name                              = "${local.name_prefix}-service"
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.app[0].arn
  launch_type                       = "FARGATE"
  desired_count                     = var.desired_count
  enable_execute_command            = true
  health_check_grace_period_seconds = 30
  wait_for_steady_state             = true
  platform_version                  = "LATEST"
  force_new_deployment              = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.app[0].id]
    subnets          = var.private_app_subnet_ids
  }

  load_balancer {
    container_name   = "fastapi"
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  depends_on = [aws_lb_listener.https]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-service"
    },
  )
}

resource "aws_route53_record" "app" {
  count = local.service_enabled && var.application_domain_name != null && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.application_domain_name
  type    = "A"

  alias {
    evaluate_target_health = true
    name                   = aws_lb.app[0].dns_name
    zone_id                = aws_lb.app[0].zone_id
  }
}
