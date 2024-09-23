# terraform/variables.tf
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-north-1"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "process_data"
}

variable "api_name" {
  description = "The name of the API Gateway"
  type        = string
  default     = "patient-data-api"
}
