provider "aws" {
  region = var.aws_region
}

provider "archive" {}

locals {
  env_vars = {
    MESSAGES_TABLE  = aws_dynamodb_table.messages.name
    ENDPOINTS_TABLE = aws_dynamodb_table.endpoints.name
  }
}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "src_send_message/send_message.py"
  output_path = "send_message.zip"
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = "ALambda"
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }

}

data "aws_iam_policy_document" "logging_policy" {
  statement {
    sid    = "ALogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "db_policy" {
  statement {
    sid    = "DBPolicy"
    effect = "Allow"

    actions = ["dynamodb:*"]

    resources = ["${aws_dynamodb_table.endpoints.arn}", aws_dynamodb_table.messages.arn,  "${aws_dynamodb_table.messages.arn}/*", "${aws_dynamodb_table.messages.arn}/index/MessagesByEndpointId"]
  }
}

resource "aws_iam_policy" "db_policy" {
  name   = "arta_db_policy"
  policy = data.aws_iam_policy_document.db_policy.json
}

resource "aws_iam_policy" "logging_policy" {
  name   = "arta_logging_policy"
  policy = data.aws_iam_policy_document.logging_policy.json
}

resource "aws_iam_role" "arta_ad_project_lambda_iam" {
  name               = "arta_ad_project_lambda_iam"
  assume_role_policy = data.aws_iam_policy_document.policy.json
  tags = {
    Owner = "Arta"
  }
}

resource "aws_iam_role_policy_attachment" "logging_policy_attachment" {
  role       = aws_iam_role.arta_ad_project_lambda_iam.name
  policy_arn = aws_iam_policy.logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "db_policy_attachment" {
  role       = aws_iam_role.arta_ad_project_lambda_iam.name
  policy_arn = aws_iam_policy.db_policy.arn
}



resource "aws_dynamodb_table" "endpoints" {
  hash_key = "endpointId"
  name     = "AdMessagingEndpoints"

  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "endpointId"
    type = "S"
  }

  attribute {
    name = "endpointAlias"
    type = "S"
  }

  attribute {
    name = "lastCheckin"
    type = "N"
  }

  global_secondary_index {
    name            = "EndpointsByAlias"
    hash_key        = "endpointAlias"
    range_key       = "lastCheckin"
    write_capacity  = 1
    read_capacity   = 1
    projection_type = "ALL"
  }


}

resource "aws_dynamodb_table" "messages" {
  hash_key = "messageId"
  name     = "AdMessagingMessages"

  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "endpointId"
    type = "S"
  }

  attribute {
    name = "delivered"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  global_secondary_index {
    name            = "MessagesByEndpointIdTS"
    hash_key        = "endpointId"
    range_key       = "timestamp"
    write_capacity  = 1
    read_capacity   = 1
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "MessagesByEndpointId"
    hash_key        = "endpointId"
    range_key       = "delivered"
    write_capacity  = 1
    read_capacity   = 1
    projection_type = "ALL"
  }
}


# LAMBDA FOR SEND MESSAGE
variable "send_message_function_name" {
  default = "send_message"
}
resource "aws_cloudwatch_log_group" "send_message" {
  name              = "/aws/lambda/${var.send_message_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "send_message" {
  function_name = var.send_message_function_name

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "send_message.lambda_handler"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "send_message" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/*/*"
}

# LAMBDA FOR GET MESSAGE BY ID
variable "get_message_by_id_handler" {
  default = "get_message_by_id"
}
resource "aws_cloudwatch_log_group" "get_message_by_id" {
  name              = "/aws/lambda/${var.get_message_by_id_handler}"
  retention_in_days = 14
}

resource "aws_lambda_function" "get_message_by_id" {
  function_name = var.get_message_by_id_handler

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.get_message_by_id_handler}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "get_message_by_id" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_message_by_id.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/*/*"
}

# LAMBDA FOR GET MESSAGE FOR ENDPOINT
variable "get_message_by_endpoint_handler" {
  default = "get_messages_for_endpoint"
}
resource "aws_cloudwatch_log_group" "get_messages_for_endpoint" {
  name              = "/aws/lambda/${var.get_message_by_endpoint_handler}"
  retention_in_days = 14
}

resource "aws_lambda_function" "get_messages_for_endpoint" {
  function_name = var.get_message_by_endpoint_handler

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.get_message_by_endpoint_handler}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "get_messages_for_endpoint" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_messages_for_endpoint.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/*/*"
}

# LAMBDA TO REGISTER NEW ENDPOING
variable "register_client" {
  default = "register_client"
}
resource "aws_cloudwatch_log_group" "register_client" {
  name              = "/aws/lambda/${var.register_client}"
  retention_in_days = 14
}

resource "aws_lambda_function" "register_client" {
  function_name = var.register_client

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.register_client}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "register_client" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_client.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/${aws_api_gateway_method.endpoint_register.http_method}/*/*"
}

###################################################################################################
###################################################################################################
#                                    API GATEWAY
###################################################################################################
# This is all the setup for API Gateway
###################################################################################################
resource "aws_api_gateway_rest_api" "ad_control_api" {
  name               = "ad_messaging_control_api"
  description        = "REST API for ad messaging system"
  binary_media_types = ["image/png"]
}

###################################################################################################
# Shared Paths
###################################################################################################

# Messages Path /messages
resource "aws_api_gateway_resource" "messages" {
  parent_id   = aws_api_gateway_rest_api.ad_control_api.root_resource_id
  path_part   = "messages"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

# Endpoints Path /endpoint
resource "aws_api_gateway_resource" "endpoint" {
  parent_id   = aws_api_gateway_rest_api.ad_control_api.root_resource_id
  path_part   = "endpoint"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

# Endpoint By Id Path /endpoint/{endpointId}
resource "aws_api_gateway_resource" "endpoints_by_id" {
  parent_id   = aws_api_gateway_resource.endpoint.id
  path_part   = "{endpointId}"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

# Messages Path /cdn
resource "aws_api_gateway_resource" "cdn" {
  parent_id   = aws_api_gateway_rest_api.ad_control_api.root_resource_id
  path_part   = "cdn"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

# Messages Path /cdn/images
resource "aws_api_gateway_resource" "images" {
  parent_id   = aws_api_gateway_resource.cdn.id
  path_part   = "images"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

# Messages Path /cdn/images/{image}
resource "aws_api_gateway_resource" "image" {
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "{image}"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}


###################################################################################################
# SEND MESSAGE
###################################################################################################
# path /send
resource "aws_api_gateway_resource" "send_message" {
  parent_id   = aws_api_gateway_resource.messages.id
  path_part   = "send"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

resource "aws_api_gateway_method" "send_message" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.send_message.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "send_message" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.send_message.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.send_message.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.send_message.invoke_arn
}

###################################################################################################
# GET MESSAGE BY ID
###################################################################################################
# path /messages/{messageId}
resource "aws_api_gateway_resource" "get_message_by_id" {
  parent_id   = aws_api_gateway_resource.messages.id
  path_part   = "{messageId+}"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

resource "aws_api_gateway_method" "get_message_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.get_message_by_id.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.messageId" = true
  }
}

resource "aws_api_gateway_integration" "get_message_by_id" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.get_message_by_id.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.get_message_by_id.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_message_by_id.invoke_arn

  request_parameters = {
    "integration.request.path.messageId" = "method.request.path.messageId"
  }
}

###################################################################################################
# GET MESSAGE FOR ENDPOINT
###################################################################################################
# path /endpoint/{endpointId}/messages
resource "aws_api_gateway_resource" "endpoint_messages_by_id" {
  parent_id   = aws_api_gateway_resource.endpoints_by_id.id
  path_part   = "messages"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

resource "aws_api_gateway_method" "get_messages_for_endpoint" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.endpoint_messages_by_id.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.endpointId" = true
  }
}

resource "aws_api_gateway_integration" "get_messages_for_endpoint" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.endpoint_messages_by_id.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.get_messages_for_endpoint.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_messages_for_endpoint.invoke_arn

  request_parameters = {
    "integration.request.path.endpointId" = "method.request.path.endpointId"
  }
}


###################################################################################################
# GET AN ENDPOINT
###################################################################################################

# LAMBDA FOR GET MESSAGE FOR ENDPOINT
variable "get_endpoint_handler" {
  default = "get_endpoint_handler"
}
resource "aws_cloudwatch_log_group" "get_endpoint" {
  name              = "/aws/lambda/${var.get_endpoint_handler}"
  retention_in_days = 14
}

resource "aws_lambda_function" "get_endpoint" {
  function_name = var.get_endpoint_handler

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.get_endpoint_handler}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "get_endpoint" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_endpoint.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/${aws_api_gateway_method.get_endpoint.http_method}/*/*"
}

#**************************************
# API GATEWAY
#
# path /endpoint/{endpointId}
#**************************************

resource "aws_api_gateway_method" "get_endpoint" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.endpoints_by_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.endpointId" = true
  }
}

resource "aws_api_gateway_integration" "get_endpoint" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.endpoints_by_id.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.get_endpoint.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_endpoint.invoke_arn
  content_handling        = "CONVERT_TO_BINARY"

  request_parameters = {
    "integration.request.path.endpointId" = "method.request.path.endpointId"
  }
}

###################################################################################################
# PREFORM A CHECKIN
###################################################################################################

# LAMBDA FOR GET MESSAGE FOR ENDPOINT
variable "endpoint_checkin_handler" {
  default = "endpoint_id_checkin"
}
resource "aws_cloudwatch_log_group" "endpoint_checkin" {
  name              = "/aws/lambda/${var.endpoint_checkin_handler}"
  retention_in_days = 14
}

resource "aws_lambda_function" "endpoint_checkin" {
  function_name = var.endpoint_checkin_handler

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.endpoint_checkin_handler}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "endpoint_checkin" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.endpoint_checkin.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/${aws_api_gateway_method.endpoint_checkin.http_method}/*/checkin"
}

#**************************************
# API GATEWAY
#
# path /endpoint/{endpointId}/checkin
#**************************************

resource "aws_api_gateway_resource" "endpoint_checkin" {
  parent_id   = aws_api_gateway_resource.endpoints_by_id.id
  path_part   = "checkin"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

resource "aws_api_gateway_method" "endpoint_checkin" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.endpoint_checkin.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.endpointId" = true
  }
}

resource "aws_api_gateway_integration" "endpoint_checkin" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.endpoint_checkin.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.endpoint_checkin.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.endpoint_checkin.invoke_arn
  content_handling        = "CONVERT_TO_BINARY"

  request_parameters = {
    "integration.request.path.endpointId" = "method.request.path.endpointId"
  }
}

###################################################################################################
# GET IMAGE
###################################################################################################

# LAMBDA FOR GET MESSAGE FOR ENDPOINT
variable "get_image_handler" {
  default = "get_image_handler"
}
resource "aws_cloudwatch_log_group" "get_image" {
  name              = "/aws/lambda/${var.get_image_handler}"
  retention_in_days = 14
}

resource "aws_lambda_function" "get_image" {
  function_name = var.get_image_handler

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.arta_ad_project_lambda_iam.arn
  handler = "${var.send_message_function_name}.${var.get_image_handler}"
  runtime = "python3.7"

  environment {
    variables = local.env_vars
  }
}

resource "aws_lambda_permission" "get_image" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_image.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/${aws_api_gateway_method.get_image.http_method}/*/*"
}

#**************************************
# API GATEWAY
#
# path /cdn/images/{image}
#**************************************

resource "aws_api_gateway_method" "get_image" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.image.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.image" = true
  }
}

resource "aws_api_gateway_integration" "get_image" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.image.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.get_image.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image.invoke_arn
  content_handling        = "CONVERT_TO_BINARY"

  request_parameters = {
    "integration.request.path.image" = "method.request.path.image"
  }
}


###################################################################################################
# REGISTER ENDPOINT
###################################################################################################
# Endpoint Register
# path /endpoint/register
resource "aws_api_gateway_resource" "endpoint_register" {
  parent_id   = aws_api_gateway_resource.endpoint.id
  path_part   = "register"
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
}

resource "aws_api_gateway_method" "endpoint_register" {
  rest_api_id   = aws_api_gateway_rest_api.ad_control_api.id
  resource_id   = aws_api_gateway_resource.endpoint_register.id
  http_method   = "POST"
  authorization = "NONE"

}

resource "aws_api_gateway_integration" "endpoint_register" {
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.endpoint_register.id
  rest_api_id             = aws_api_gateway_rest_api.ad_control_api.id
  http_method             = aws_api_gateway_method.endpoint_register.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.register_client.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = ["aws_api_gateway_integration.send_message", "aws_api_gateway_integration.get_message_by_id", "aws_api_gateway_integration.get_messages_for_endpoint", "aws_api_gateway_integration.endpoint_register", "aws_api_gateway_integration.endpoint_checkin", "aws_lambda_function.endpoint_checkin", "aws_api_gateway_integration.get_endpoint", "aws_api_gateway_integration.get_image"]
  rest_api_id = aws_api_gateway_rest_api.ad_control_api.id
  stage_name  = "prod"
  variables = {
    timestamp = timestamp()
  }
}