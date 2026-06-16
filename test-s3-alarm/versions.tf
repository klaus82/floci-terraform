terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "cm-test-s3-notification"
    key    = "test-s3-alarm/terraform.tfstate"
    region = "eu-west-1"
  }
}
