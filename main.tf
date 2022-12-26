provider "aws" {
  region = "us-east-1"
}

# define some variables first
variable "lambda_function" {
  default = "ssl_checkerino_iac"
}
variable "myregion" {
    default = "us-east-1"
}

# user-prompting variables
variable "accountId" {}

variable "email_var" {}

# Create an IAM role for the lambda function as well as the ability to publish to sns
resource "aws_iam_role" "iam_for_lambda_iac" {
  name = "iam_for_lambda_iac"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
            }
        ]
    }
EOF
}


resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "ssl_checkerino_iac.zip"
  function_name = "ssl_checkerino_iac"
  role          = aws_iam_role.iam_for_lambda_iac.arn
  handler       = "ssl_checkerino.ssl_checkerino"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("ssl_checkerino_iac.zip")

  runtime = "python3.9"

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${var.lambda_function}"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_iac"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "sns_policy" {
  name        = "sns_policy"
  description = "Policy for publishing to an SNS queue"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:${var.myregion}:${var.accountId}:${aws_sns_topic.ssl_notifier.name}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sns_policy" {
  role       = aws_iam_role.iam_for_lambda_iac.name
  policy_arn = aws_iam_policy.sns_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda_iac.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_api_gateway_rest_api" "ssl_api" {
  name        = "ssl_api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "ssl_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.ssl_api.id
  parent_id   = aws_api_gateway_rest_api.ssl_api.root_resource_id
  path_part   = "resource"
}

resource "aws_api_gateway_method" "example" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.ssl_api_resource.id
  rest_api_id   = aws_api_gateway_rest_api.ssl_api.id
}


resource "aws_api_gateway_integration" "integration" {
  http_method = aws_api_gateway_method.example.http_method
  resource_id = aws_api_gateway_resource.ssl_api_resource.id
  rest_api_id = aws_api_gateway_rest_api.ssl_api.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = aws_lambda_function.test_lambda.invoke_arn 
}


resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.ssl_api.id}/*/${aws_api_gateway_method.example.http_method}${aws_api_gateway_resource.ssl_api_resource.path}"
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.ssl_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.ssl_api_resource.id,
      aws_api_gateway_method.example.id,
      aws_api_gateway_integration.integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.ssl_api.id
  stage_name = "default"
}

resource "aws_sns_topic" "ssl_notifier" {
  name = "ssl_notifier_iac"
}

resource "aws_sns_topic_subscription" "ssl_subscription" {
  topic_arn = aws_sns_topic.ssl_notifier.arn
  protocol  = "email"
  endpoint  = var.email_var
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.ssl_notifier.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.accountId,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.ssl_notifier.arn,
    ]

    sid = "__default_statement_ID"
  }
}

resource "aws_lambda_function_event_invoke_config" "ssl_notifier" {
  function_name = aws_lambda_function.test_lambda.function_name

  destination_config {
    on_failure {
      destination = aws_sns_topic.ssl_notifier.arn
    }

    on_success {
      destination = aws_sns_topic.ssl_notifier.arn
    }
  }
}

# output the ARN for the sns queue so you can update the python script
output "sns_Arn" {
  value = "arn:aws:sns:${var.myregion}:${var.accountId}:${aws_sns_topic.ssl_notifier.name}"
}
