# test-s3-alarm

End-to-end test of the **S3 → EventBridge → SNS** near real-time change alarm, running entirely on [Floci](https://floci.io) (local AWS emulator).

## Prerequisites

- Docker and Docker Compose
- Terraform >= 1.6
- AWS CLI

Set these env vars once in your shell to avoid repeating flags on every command:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

Floci doesn't validate credentials — the values for region, key ID, and secret can be anything non-empty.

---

## 1. Start Floci

From the repo root:

```bash
docker compose up -d --build
```

Wait a few seconds for Floci to be ready:

```bash
docker compose logs -f floci
# ready when you see: === AWS Local Emulator Ready ===
```

The following services will be running:

| Service | URL | Description |
|---------|-----|-------------|
| Floci | http://localhost:4566 | AWS emulator (S3, SNS, SQS, EventBridge, …) |
| Floci UI | http://localhost:3000 | Visual dashboard to browse resources |
| Floci API | http://localhost:3001 | Backend API for the UI |

---

## 2. Apply Terraform

```bash
cd test-s3-alarm
terraform init
terraform apply -auto-approve
```

Expected: **7 resources created**

```
aws_s3_bucket.wp_bucket
aws_s3_bucket_notification.wp_bucket_eventbridge[0]
aws_sns_topic.wp_s3_change_alarm[0]
aws_sns_topic_policy.wp_s3_change_alarm[0]
aws_sns_topic_subscription.wp_s3_change_alarm_email[0]
aws_cloudwatch_event_rule.wp_s3_change[0]
aws_cloudwatch_event_target.wp_s3_change_sns[0]
```

---

## 3. Create an SQS test inbox

SNS delivers to subscribers — messages aren't stored on the topic. Subscribe an SQS queue to capture them:

```bash
# Create the queue
aws sqs create-queue --queue-name test-inbox

# Subscribe it to the SNS topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:000000000000:hse-dev-example-com-s3-change-alarm \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:test-inbox
```

---

## 4. Trigger an S3 event

Upload any file to `wp-bucket-test`:

```bash
aws s3 cp /dev/null s3://wp-bucket-test/test.txt
```

---

## 5. Verify the message arrived

```bash
aws sqs receive-message \
  --queue-url http://localhost:4566/000000000000/test-inbox \
  --max-number-of-messages 10
```

You should see a message whose `Body` contains an SNS notification envelope wrapping the EventBridge event:

```json
{
  "Type": "Notification",
  "TopicArn": "arn:aws:sns:us-east-1:000000000000:hse-dev-example-com-s3-change-alarm",
  "Message": "{\"source\":\"aws.s3\",\"detail-type\":\"Object Created\", ...}"
}
```

You can also browse the created resources visually at **http://localhost:3000**.

---

## 6. Teardown

```bash
# From test-s3-alarm/
terraform destroy -auto-approve

# Stop Floci
cd ..
docker compose down
```
