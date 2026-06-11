resource "aws_s3_bucket_notification" "wp_bucket_eventbridge" {
  count  = var.enable_s3_change_alarm ? 1 : 0
  bucket = aws_s3_bucket.wp_bucket.id

  eventbridge = true
}

resource "aws_sns_topic" "wp_s3_change_alarm" {
  count = var.enable_s3_change_alarm ? 1 : 0
  name  = "hse-${replace(local.fqdn, ".", "-")}-s3-change-alarm"

  tags = {
    Name = "hse-${local.fqdn}-s3-change-alarm"
  }
}

resource "aws_sns_topic_policy" "wp_s3_change_alarm" {
  count = var.enable_s3_change_alarm ? 1 : 0
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
  name        = "hse-${replace(local.fqdn, ".", "-")}-s3-change"
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
    Name = "hse-${local.fqdn}-s3-change"
  }
}

resource "aws_cloudwatch_event_target" "wp_s3_change_sns" {
  count = var.enable_s3_change_alarm ? 1 : 0
  rule  = aws_cloudwatch_event_rule.wp_s3_change[0].name
  arn   = aws_sns_topic.wp_s3_change_alarm[0].arn
}
