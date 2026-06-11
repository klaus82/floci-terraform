locals {
  fqdn = "dev.example.com"
}

resource "aws_s3_bucket" "wp_bucket" {
  bucket = "wp-bucket-test"
}
