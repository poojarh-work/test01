provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "patient_data" {
  bucket = "patient-data-records"
}

# S3 Bucket Notification to trigger Lambda
resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  bucket = aws_s3_bucket.patient_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_data.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""      # Optional: specify a folder
    filter_suffix       = ".json" # Optional: specify a file type
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Allow S3 to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_data.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.patient_data.arn
}

resource "aws_dynamodb_table" "processed_data" {
  name         = "processed_data"
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "id"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to the IAM Role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda_s3_access_policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::patient-data*",
          "arn:aws:s3:::patient-data/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_access_policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:aws:dynamodb:eu-north-1:931622661747:table/processed_data"
      }
    ]
  })
}

resource "aws_lambda_function" "process_data" {
  filename         = "../lambda.zip"
  function_name    = "process_data"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("../lambda.zip")
}

resource "aws_api_gateway_rest_api" "api" {
  name = "patient-data-api"
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_method" "post_data" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.post_data.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.process_data.arn}/invocations"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_stage" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"

  triggers = {
    redeploy = "${timestamp()}"
  }
}

output "api_endpoint" {
  value = "${aws_api_gateway_deployment.api_stage.invoke_url}/data"
}
