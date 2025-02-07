#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name            = "windowsexample"
  vpc_cidr        = "10.0.0.0/16"
  aws_region      = "us-west-2"
  azs             = slice(data.aws_availability_zones.available.names, 0, 1)
  build_version   = "0.0.1"
  test_version    = "0.0.1"
  build_file_name = "win2022build.yaml"
  test_file_name  = "win2022test.yaml"
  tags = {
    #description = "Tags applied to the role and AWS Resources"
    created-by         = "Terraform"
    dataclassification = "internal"
    owner              = "Test"
  }
}

module "ec2-image-builder" {
  #  source                = "aws-ia/ec2-image-builder/aws"
  source                                = "../.."
  name                                  = local.name
  aws_region                            = local.aws_region
  vpc_id                                = module.vpc.vpc_id
  subnet_id                             = module.vpc.private_subnets[0]
  source_cidr                           = [local.vpc_cidr] #["<ENTER your IP here to access EC2 Image Builder Instances through RDP or SSH>]"
  create_security_group                 = true
  instance_types                        = ["c5.large"]
  instance_key_pair                     = aws_key_pair.imagebuilder.key_name
  source_ami_name                       = "Windows_Server-2022-English-Core-Base-*"
  ami_name                              = "Windows 2022 core AMI"
  ami_description                       = "Windows 2022 core AMI provided by AWS"
  recipe_version                        = "0.0.1"
  build_component_arn                   = [aws_imagebuilder_component.win2022build.arn]
  test_component_arn                    = [aws_imagebuilder_component.win2022test.arn]
  s3_bucket_name                        = aws_s3_bucket.ec2_image_builder_components.id
  attach_custom_policy                  = true
  custom_policy_arn                     = aws_iam_policy.policy.arn
  platform                              = "Windows"
  imagebuilder_image_recipe_kms_key_arn = aws_kms_key.imagebuilder_image_recipe_kms_key.arn
  tags                                  = local.tags

  managed_components = [{
    name    = "powershell-lts-windows",
    version = "7.4.0"
    },
    {
      name    = "chocolatey",
      version = "1.0.0"
  }]

  target_account_ids = [] #"<ENTER TARGET AWS ACCOUNT IDS.>"

  #For Unencrypted AMI
  ami_regions_kms_key = {} # "<ENTER TARGET AWS REGION TO SHARE THE AMI WITH>" = ""

  #or
  #for Encrypt AMI
  #ami_regions_kms_key = {
  #  "<ENTER TARGET AWS REGION TO SHARE THE AMI WITH>" = "<ENTER KMS KEYs TO ENCRYPT AMIs ON THE TARGET REGION>"
  #}

}

resource "aws_kms_key" "imagebuilder_image_recipe_kms_key" {
  description         = "Imagebuilder Image Recipe KMS key"
  enable_key_rotation = true
  policy              = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

resource "aws_s3_object" "upload_scripts" {
  for_each = fileset("./scripts/", "**/*")

  bucket = aws_s3_bucket.ec2_image_builder_components.id
  key    = "./scripts/${each.value}"
  source = "./scripts/${each.value}"
  etag   = filemd5("./scripts/${each.value}")
  tags   = local.tags
}

resource "aws_kms_key" "aws_imagebuilder_component_kms_key" {
  description         = "Imagebuilder Component KMS key"
  enable_key_rotation = true
  policy              = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

resource "aws_imagebuilder_component" "win2022build" {

  name       = "win2022build"
  version    = local.build_version
  kms_key_id = aws_kms_key.aws_imagebuilder_component_kms_key.arn
  platform   = "Windows"
  uri        = "s3://${aws_s3_bucket.ec2_image_builder_components.id}/${local.build_file_name}"

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_s3_object.win2022build
  ]
  tags = local.tags
}

resource "aws_s3_object" "win2022build" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id
  key    = local.build_file_name
  source = local.build_file_name
  etag   = filemd5("${path.module}/${local.build_file_name}")
  tags   = local.tags
}

resource "aws_imagebuilder_component" "win2022test" {

  name       = "win2022test"
  version    = local.test_version
  kms_key_id = aws_kms_key.aws_imagebuilder_component_kms_key.arn
  platform   = "Windows"
  uri        = "s3://${aws_s3_bucket.ec2_image_builder_components.id}/${local.test_file_name}"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_s3_object.win2022test
  ]
}

resource "aws_s3_object" "win2022test" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id
  key    = local.test_file_name
  source = local.test_file_name
  etag   = filemd5("${path.module}/${local.test_file_name}")
  tags   = local.tags
}

resource "aws_iam_policy" "policy" {

  name        = "custom_policy_windows"
  path        = "/"
  description = "My custom policy"
  policy      = data.aws_iam_policy_document.iam_policy_document.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "iam_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:PutObjectAcl",
    ]
    resources = [aws_s3_bucket.ec2_image_builder_components.arn,
    "${aws_s3_bucket.ec2_image_builder_components.arn}/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.ec2_image_builder_components.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey"
    ]
    resources = [aws_kms_key.aws_imagebuilder_component_kms_key.arn,
    aws_kms_key.aws_s3_bucket_kms_key.arn]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      },
      "Action": [ "s3:*" ],
      "Resource": [
        "${aws_s3_bucket.ec2_image_builder_components.arn}",
        "${aws_s3_bucket.ec2_image_builder_components.arn}/*"
      ]
    },
    {
  "Sid": "Deny non-HTTPS access",
  "Effect": "Deny",
  "Principal": "*",
  "Action": [ "s3:*" ],
  "Resource": "${aws_s3_bucket.ec2_image_builder_components.arn}/*",
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
            }
      }
  }
  ]
}
EOF
}

resource "random_uuid" "random_uuid" {
}

resource "aws_kms_key" "aws_s3_bucket_kms_key" {
  description         = "S3 Bucket KMS key"
  enable_key_rotation = true
  policy              = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "ec2_image_builder_components" {
  bucket        = "${local.name}-components-${random_uuid.random_uuid.result}"
  force_destroy = true
  #checkov:skip=CKV2_AWS_61:No Lifecycle configuration for this example
  #checkov:skip=CKV_AWS_18:No access logging configured for this example
  #checkov:skip=CKV2_AWS_62:No event notifications configured for this example
  #checkov:skip=CKV_AWS_144:No cross-region replication configured for this example
  lifecycle {
    ignore_changes = [
      grant
    ]
  }
  tags = local.tags
}


#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "ec2_image_builder_components_encryption" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.aws_s3_bucket_kms_key.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "ec2_image_builder_components_versioning" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Key Pair
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "aws_ssm_parameter_kms_key" {
  description         = "SSM Parameter KMS key"
  enable_key_rotation = true
  policy              = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

resource "tls_private_key" "imagebuilder" {
  algorithm = "RSA"
}

resource "aws_key_pair" "imagebuilder" {
  key_name   = "${local.name}-key-pair"
  public_key = tls_private_key.imagebuilder.public_key_openssh
}

resource "aws_ssm_parameter" "imagebuilder_ssh_private_key_pem" {
  name   = "/${local.name}/imagebuilder_ssh_private_key_pem"
  type   = "SecureString"
  value  = tls_private_key.imagebuilder.private_key_pem
  key_id = aws_kms_key.aws_ssm_parameter_kms_key.arn
}

resource "aws_ssm_parameter" "imagebuilder_ssh_public_key_pem" {
  name   = "/${local.name}/imagebuilder_ssh_public_key_pem"
  type   = "SecureString"
  value  = tls_private_key.imagebuilder.public_key_pem
  key_id = aws_kms_key.aws_ssm_parameter_kms_key.arn
}

resource "aws_ssm_parameter" "imagebuilder_ssh_public_key_openssh" {
  name   = "/${local.name}/imagebuilder_ssh_public_key_openssh"
  type   = "SecureString"
  value  = tls_private_key.imagebuilder.public_key_openssh
  key_id = aws_kms_key.aws_ssm_parameter_kms_key.arn
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}