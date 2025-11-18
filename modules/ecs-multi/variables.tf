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
Map of ECS clusters to create. Each cluster defines launch type / capacity provider preferences,
logging / monitoring options, and a nested list of services.
EOT

  type = map(object({
    # Cluster-level config
    name        = string
    launch_type = optional(string, "FARGATE") # FARGATE or EC2

    # Cluster-level logging / monitoring
    enable_container_insights = optional(bool, true)

    # Optional cluster capacity providers (e.g., ["FARGATE", "FARGATE_SPOT"])
    capacity_providers = optional(list(string), [])

    # Nested services for this cluster
    services = list(object({
      # Service basics
      name          = string
      desired_count = number

      # Either use launch_type (falls back to cluster.launch_type),
      # or capacity_provider_strategy (in which case launch_type is NOT sent to the service).
      launch_type = optional(string)

      capacity_provider_strategy = optional(list(object({
        capacity_provider = string
        weight            = optional(number)
        base              = optional(number)
      })), [])

      # Task roles
      task_execution_role_arn = string
      task_role_arn           = optional(string)

      # Container definition (single main container)
      container_image = string
      container_port  = number
      cpu             = number
      memory          = number

      environment = optional(map(string), {})

      # Logging options
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
