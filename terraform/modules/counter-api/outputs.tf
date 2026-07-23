output "api_endpoint" {
  description = "The base invoke URL for the API — append /count to call the counter"
  value       = aws_apigatewayv2_api.counter.api_endpoint
}

output "table_name" {
  description = "Name of the DynamoDB table holding the counter"
  value       = aws_dynamodb_table.counter.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function — useful for viewing logs"
  value       = aws_lambda_function.counter.function_name
}
