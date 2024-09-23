# terraform/outputs.tf
output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.process_data.arn
}

#output "api_endpoint" {
#  description = "The URL of the API Gateway endpoint"
#  value       = "${aws_api_gateway_deployment.api_stage.invoke_url}/data"
#}
