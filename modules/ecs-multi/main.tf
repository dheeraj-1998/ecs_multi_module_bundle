terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Flatten clusters + services into a single map keyed by "clusterKey:serviceName"
  services = merge([
    for cluster_key, cluster in var.clusters : {
      for svc in cluster.services : "${cluster_key}:${svc.name}" => {
        cluster_key  = cluster_key
        cluster_name = cluster.name

        # Service launch type (FARGATE or EC2) – service override or cluster default
        launch_type = upper(coalesce(
          try(svc.launch_type, null),
          cluster.launch_type
        ))

        service = svc
      }
    }
  ]...)
}

# One ECS cluster per item in var.clusters
resource "aws_ecs_cluster" "this" {
  for_each = var.clusters

  name = each.value.name

  tags = merge(
    var.default_tags,
    {
      "Cluster" = each.value.name
    }
  )
}

# One log group per service
resource "aws_cloudwatch_log_group" "service" {
  for_each = local.services

  name              = "/ecs/${each.value.cluster_name}/${each.value.service.name}"
  retention_in_days = try(each.value.service.log_retention_in_days, 30)

  tags = merge(
    var.default_tags,
    {
      "Cluster" = each.value.cluster_name
      "Service" = each.value.service.name
    }
  )
}

# One task definition per service
resource "aws_ecs_task_definition" "service" {
  for_each = local.services

  family = "${each.value.cluster_name}-${each.value.service.name}"

  requires_compatibilities = [each.value.launch_type] # FARGATE or EC2
  network_mode             = "awsvpc"

  cpu    = tostring(each.value.service.cpu)
  memory = tostring(each.value.service.memory)

  execution_role_arn = each.value.service.task_execution_role_arn
  task_role_arn      = try(each.value.service.task_role_arn, null)

  container_definitions = jsonencode([
    {
      name      = each.value.service.name
      image     = each.value.service.container_image
      cpu       = each.value.service.cpu
      memory    = each.value.service.memory
      essential = true

      portMappings = [
        {
          containerPort = each.value.service.container_port
          hostPort      = each.value.service.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        for k, v in try(each.value.service.environment, {}) : {
          name  = k
          value = v
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.service.name
        }
      }
    }
  ])

  tags = merge(
    var.default_tags,
    {
      "Cluster" = each.value.cluster_name
      "Service" = each.value.service.name
    }
  )
}

# One ECS service per nested service object
resource "aws_ecs_service" "service" {
  for_each = local.services

  name            = each.value.service.name
  cluster         = aws_ecs_cluster.this[each.value.cluster_key].id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.service.desired_count

  launch_type = each.value.launch_type

  network_configuration {
    subnets          = each.value.service.subnets
    security_groups  = each.value.service.security_groups
    assign_public_ip = try(each.value.service.assign_public_ip, false) ? "ENABLED" : "DISABLED"
  }

  # Optional load balancer association
  dynamic "load_balancer" {
    for_each = try(each.value.service.load_balancer, null) == null ? [] : [each.value.service.load_balancer]

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = coalesce(
        try(load_balancer.value.container_name, null),
        each.value.service.name
      )
      container_port = coalesce(
        try(load_balancer.value.container_port, null),
        each.value.service.container_port
      )
    }
  }

  tags = merge(
    var.default_tags,
    {
      "Cluster" = each.value.cluster_name
      "Service" = each.value.service.name
    }
  )
}
