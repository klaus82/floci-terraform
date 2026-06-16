resource "aws_s3_bucket_notification" "wp_bucket_eventbridge" {
  count  = var.enable_s3_change_alarm ? 1 : 0
  bucket = aws_s3_bucket.wp_bucket.id

  eventbridge = true
}

resource "aws_sns_topic" "wp_s3_change_alarm" {
  count = var.enable_s3_change_alarm && var.s3_change_alarm_email != null ? 1 : 0
  name  = "claudio-${replace(local.fqdn, ".", "-")}-s3-change-alarm"

  tags = {
    Name = "claudio-${local.fqdn}-s3-change-alarm"
  }
}

resource "aws_sns_topic_policy" "wp_s3_change_alarm" {
  count = var.enable_s3_change_alarm && var.s3_change_alarm_email != null ? 1 : 0
  arn   = aws_sns_topic.wp_s3_change_alarm[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.wp_s3_change_alarm[0].arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "wp_s3_change_alarm_email" {
  count     = var.enable_s3_change_alarm && var.s3_change_alarm_email != null ? 1 : 0
  topic_arn = aws_sns_topic.wp_s3_change_alarm[0].arn
  protocol  = "email"
  endpoint  = var.s3_change_alarm_email
}

resource "aws_cloudwatch_event_rule" "wp_s3_change" {
  count       = var.enable_s3_change_alarm ? 1 : 0
  name        = "claudio-${replace(local.fqdn, ".", "-")}-s3-change"
  description = "Fires when objects are created or deleted in ${aws_s3_bucket.wp_bucket.bucket}"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created", "Object Deleted"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.wp_bucket.bucket]
      }
    }
  })

  tags = {
    Name = "claudio-${local.fqdn}-s3-change"
  }
}

resource "aws_cloudwatch_event_target" "wp_s3_change_sns" {
  count = var.enable_s3_change_alarm && var.s3_change_alarm_email != null ? 1 : 0
  rule  = aws_cloudwatch_event_rule.wp_s3_change[0].name
  arn   = aws_sns_topic.wp_s3_change_alarm[0].arn
}

locals {
  datadog_endpoint = var.datadog_invocation_endpoint != null ? var.datadog_invocation_endpoint : "https://api.${var.datadog_site}/api/v1/events"
}

resource "aws_cloudwatch_event_connection" "datadog" {
  count              = var.enable_s3_change_alarm && var.datadog_api_key != null ? 1 : 0
  name               = "claudio-datadog"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "DD-API-KEY"
      value = var.datadog_api_key
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "datadog" {
  count               = var.enable_s3_change_alarm && var.datadog_api_key != null ? 1 : 0
  name                = "claudio-datadog-events"
  connection_arn      = aws_cloudwatch_event_connection.datadog[0].arn
  invocation_endpoint = local.datadog_endpoint
  http_method         = "POST"
}

resource "aws_iam_role" "eventbridge_datadog" {
  count = var.enable_s3_change_alarm && var.datadog_api_key != null ? 1 : 0
  name  = "claudio-eventbridge-datadog"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_datadog" {
  count  = var.enable_s3_change_alarm && var.datadog_api_key != null ? 1 : 0
  role   = aws_iam_role.eventbridge_datadog[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:InvokeApiDestination"
      Resource = aws_cloudwatch_event_api_destination.datadog[0].arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "wp_s3_change_datadog" {
  count    = var.enable_s3_change_alarm && var.datadog_api_key != null ? 1 : 0
  rule     = aws_cloudwatch_event_rule.wp_s3_change[0].name
  arn      = aws_cloudwatch_event_api_destination.datadog[0].arn
  role_arn = aws_iam_role.eventbridge_datadog[0].arn

  input_transformer {
    input_paths = {
      bucket    = "$.detail.bucket.name"
      key       = "$.detail.object.key"
      eventType = "$.detail-type"
      time      = "$.time"
    }
    input_template = <<-EOT
      {
        "title": "S3 change detected in <bucket>",
        "text": "<eventType> — object: <key> at <time>",
        "alert_type": "warning",
        "source_type_name": "amazon web services",
        "tags": ["bucket:<bucket>", "s3:change", "env:dev"]
      }
    EOT
  }
}
