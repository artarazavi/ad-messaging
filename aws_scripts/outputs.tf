output "send_message_url" {
  value = aws_lambda_function.send_message.invoke_arn
}

output "send_message_api" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}

output "api_url" {
  value = aws_api_gateway_deployment.deployment.execution_arn
}

output "get_immage_arn" {
  value = aws_api_gateway_integration.get_image.resource_id
}