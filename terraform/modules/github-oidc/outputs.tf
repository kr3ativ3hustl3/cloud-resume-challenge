output "role_arn" {
  description = "ARN GitHub Actions workflows will assume — paste this into your workflow YAML files"
  value       = aws_iam_role.github_actions.arn
}
