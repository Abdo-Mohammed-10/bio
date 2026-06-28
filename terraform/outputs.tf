# هتحتاج القيم دي بعدين في GitHub Actions

output "ecr_repository_url" {
  description = "ECR URL — هتحطه في GitHub Secrets"
  value       = aws_ecr_repository.portfolio.repository_url
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}