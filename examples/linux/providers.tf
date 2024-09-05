terraform {
<<<<<<< HEAD
  required_version = ">= 1.4.0"
=======
>>>>>>> 748f378 (add linux example + overall enhancements)
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
<<<<<<< HEAD
     awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.24.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0, < 4.0.0"
=======
    awscc = {
      source  = "hashicorp/awscc"
    }
    tls = {
      source  = "hashicorp/tls"
    }
    random = {
      source  = "hashicorp/random"
>>>>>>> 748f378 (add linux example + overall enhancements)
    }
  }
}

provider "aws" {
  region = local.aws_region
}
