terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Example IAM roles (simplified; adjust for real use)
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Dummy subnet and SG IDs should be replaced with real ones in your environment
# and any target group ARNs if using a load balancer.

module "ecs_multi" {
  source = "./modules/ecs-multi"

  aws_region = "us-east-1"

  default_tags = {
    Project = "demo"
    Env     = "dev"
  }

  clusters = {
    app_cluster = {
      name        = "app-cluster"
      launch_type = "FARGATE"

      enable_container_insights = true
      capacity_providers        = ["FARGATE"]

      services = [
        {
          name          = "api-service"
          desired_count = 2

          launch_type                = "FARGATE"
          capacity_provider_strategy = []

          task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
          task_role_arn           = aws_iam_role.ecs_task.arn

          container_image = "nginx:1.27"
          container_port  = 80
          cpu             = 256
          memory          = 512

          environment = {
            APP_ENV = "dev"
          }

          log_retention_in_days = 14

          subnets          = ["subnet-abc123", "subnet-def456"]
          security_groups  = ["sg-1234567890abcdef0"]
          assign_public_ip = true

          # Example with load balancer (replace ARN with a real one)
          load_balancer = {
            target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/example/abcd1234abcd1234"
            container_name   = "api-service"
            container_port   = 80
          }
        },
        {
          name          = "worker-service"
          desired_count = 1

          launch_type                = "FARGATE"
          capacity_provider_strategy = []

          task_execution_role_arn = aws_iam_role.ecs_task_execution.arn

          container_image = "busybox"
          container_port  = 8080
          cpu             = 256
          memory          = 512

          environment           = {}
          log_retention_in_days = 7

          subnets          = ["subnet-abc123", "subnet-def456"]
          security_groups  = ["sg-1234567890abcdef0"]
          assign_public_ip = false

          # No load_balancer field -> no LB attached
        }
      ]
    }

    batch_cluster = {
      name        = "batch-cluster"
      launch_type = "EC2"

      enable_container_insights = false
      capacity_providers        = []

      services = [
        {
          name          = "batch-worker"
          desired_count = 1

          launch_type                = "EC2"
          capacity_provider_strategy = []

          task_execution_role_arn = aws_iam_role.ecs_task_execution.arn

          container_image = "amazonlinux"
          container_port  = 9000
          cpu             = 512
          memory          = 1024

          environment           = {}
          log_retention_in_days = 30

          subnets          = ["subnet-xyz123", "subnet-xyz456"]
          security_groups  = ["sg-abcdefabcdefabcd"]
          assign_public_ip = false
        }
      ]
    }
  }
}
