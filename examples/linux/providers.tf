terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    awscc = {
      source  = "hashicorp/awscc"
    }
    tls = {
      source  = "hashicorp/tls"
    }
    random = {
      source  = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = local.aws_region
}
