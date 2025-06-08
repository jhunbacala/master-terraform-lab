provider "aws" {
  region = "us-east-1" # Adjust to your preferred region
}

# Data source to get all EC2 instances
data "aws_instances" "all_instances" {}

# CloudWatch Metric Alarm for each EC2 instance
resource "aws_cloudwatch_metric_alarm" "long_running_ec2" {
  for_each = toset(data.aws_instances.all_instances.ids)

  alarm_name          = "long-running-ec2-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  alarm_description   = "Alerts if EC2 instance ${each.key} is running for more than 30 minutes"
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

  metric_query {
    id          = "running"
    expression  = "IF(status > 0, 0, 1)" # Inverse of status check failed to detect running state
    label       = "InstanceRunning"
    return_data = true
  }

  metric_query {
    id          = "status"
    metric {
      metric_name = "StatusCheckFailed"
      namespace   = "AWS/EC2"
      period      = 3600 # 1 hour in seconds
      stat        = "Maximum"
      dimensions = {
        InstanceId = each.key
      }
    }
  }
}

# SNS Topic for notifications
resource "aws_sns_topic" "alarm_topic" {
  name = "ec2-long-running-alarm"
}

# SNS Topic Subscription (modify with your email)
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "email"
  endpoint  = "jhun.bacala@gmail.com" # Replace with your email
}
