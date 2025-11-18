output "cluster_ids" {
  description = "Map of cluster keys to ECS cluster IDs"
  value       = { for k, v in aws_ecs_cluster.this : k => v.id }
}

output "cluster_arns" {
  description = "Map of cluster keys to ECS cluster ARNs"
  value       = { for k, v in aws_ecs_cluster.this : k => v.arn }
}

output "service_arns" {
  description = "Map of 'clusterKey:serviceName' to ECS service ARNs"
  value       = { for k, v in aws_ecs_service.service : k => v.arn }
}

output "task_definition_arns" {
  description = "Map of 'clusterKey:serviceName' to task definition ARNs"
  value       = { for k, v in aws_ecs_task_definition.service : k => v.arn }
}
