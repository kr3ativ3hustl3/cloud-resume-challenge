##############################################################################
# COUNTER API MODULE
#
# Creates: a DynamoDB table (single counter item), a Python Lambda that
# atomically increments it, an HTTP API (API Gateway v2 — cheaper and
# simpler than the older REST API type for a use case this small) that
# exposes it publicly, and CORS configuration so the frontend's
# browser JS can call it directly.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

##############################################################################
# DynamoDB — single item, atomic increments via UpdateItem + ADD.
# PAY_PER_REQUEST means zero cost when idle, which matters a lot for a
# portfolio project with sporadic traffic.
##############################################################################

resource "aws_dynamodb_table" "counter" {
  name         = "cloud-resume-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}

##############################################################################
# Lambda function
##############################################################################

# Packages backend/lambda/counter.py into a zip Terraform can deploy.
#
# Deliberately NOT using a Terraform-managed approach here (neither
# the `archive` provider's data source, nor a `null_resource` +
# local-exec) — both are separately-compiled plugin binaries, and both
# turned out to require a newer macOS/OS version than every provider
# in this project has needed so far, breaking on some machines outright.
#
# Instead, this expects a pre-built zip to already exist at
# counter.zip in this module's directory, built by running
# backend/lambda/build.sh before `terraform apply`. This has zero
# provider dependencies beyond the two (aws, cloudflare) already in
# use, and mirrors how a real CI/CD pipeline separates a "build" step
# from a "deploy" step — which Phase 4 will formalize properly.

resource "aws_iam_role" "lambda_exec" {
  name = "cloud-resume-counter-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project = "cloud-resume-challenge"
  }
}

# AWS's own managed policy for basic Lambda CloudWatch Logs permissions
# (CreateLogGroup/CreateLogStream/PutLogEvents). Using the managed
# policy here rather than a hand-rolled one is the standard, AWS-
# recommended approach — logging permissions are the same for nearly
# every Lambda function, so there's little value in reinventing this
# one, unlike the DynamoDB permission below which IS scoped tightly
# since it's specific to this function's actual job.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least-privilege: this function can ONLY call UpdateItem, and ONLY on
# this one table. It can't read other tables, can't delete items,
# can't scan the table, etc.
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "cloud-resume-counter-dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:UpdateItem"
      Resource = aws_dynamodb_table.counter.arn
    }]
  })
}

# Explicit log retention — without this, Lambda log groups keep data
# forever by default, which is unnecessary cost and clutter for a
# personal project.
resource "aws_cloudwatch_log_group" "counter" {
  name              = "/aws/lambda/cloud-resume-counter"
  retention_in_days = 14

  tags = {
    Project = "cloud-resume-challenge"
  }
}

resource "aws_lambda_function" "counter" {
  function_name    = "cloud-resume-counter"
  filename         = "${path.module}/counter.zip"
  source_code_hash = filebase64sha256("${path.module}/counter.zip")
  role             = aws_iam_role.lambda_exec.arn
  handler          = "counter.handler"
  runtime          = "python3.12"
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.counter.name
      COUNTER_ID     = "visits"
      ALLOWED_ORIGIN = var.allowed_origin
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.lambda_dynamodb,
    aws_cloudwatch_log_group.counter,
  ]

  tags = {
    Project = "cloud-resume-challenge"
  }
}

##############################################################################
# API Gateway (HTTP API) — the newer, simpler, cheaper API Gateway
# type. For a use case this small (one route, no auth, no request
# validation), the older REST API type would just add cost and
# configuration surface with no real benefit.
##############################################################################

resource "aws_apigatewayv2_api" "counter" {
  name          = "cloud-resume-counter-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [var.allowed_origin]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}

resource "aws_apigatewayv2_integration" "counter" {
  api_id                 = aws_apigatewayv2_api.counter.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.counter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "counter" {
  api_id    = aws_apigatewayv2_api.counter.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.counter.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.counter.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Project = "cloud-resume-challenge"
  }
}

# Grants API Gateway permission to invoke this specific Lambda function
# — without this, API Gateway would get an authorization error trying
# to call it, even though the route is configured correctly.
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.counter.execution_arn}/*/*"
}
