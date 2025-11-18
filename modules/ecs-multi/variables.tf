variable "aws_region" {
  description = "AWS region for CloudWatch logs."
  type        = string
}

variable "default_tags" {
  description = "Default tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "clusters" {
  description = <<EOT
Map of ECS clusters to create. Each cluster has a name, a launch type, and a list of services.
Each service defines basic task settings, networking, and optional load balancer.
EOT

  type = map(object({
    name        = string
    launch_type = optional(string, "FARGATE") # FARGATE or EC2

    services = list(object({
      # Service basics
      name          = string
      desired_count = number

      # Per-service launch type override (falls back to cluster.launch_type)
      launch_type = optional(string)

      # Task roles
      task_execution_role_arn = string
      task_role_arn           = optional(string)

      # Container definition (single main container)
      container_image = string
      container_port  = number
      cpu             = number
      memory          = number

      environment = optional(map(string), {})

      # Logging
      log_retention_in_days = optional(number, 30)

      # Networking
      subnets          = list(string)
      security_groups  = list(string)
      assign_public_ip = optional(bool, false)

      # Optional load balancer association
      load_balancer = optional(object({
        target_group_arn = string
        container_name   = optional(string)
        container_port   = optional(number)
      }))
    }))
  }))
}
