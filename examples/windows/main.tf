#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

data "aws_caller_identity" "current" {}

locals {
  name            = "myfirstpipeline"
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
  source                = "aws-ia/ec2-image-builder/aws"
  name                  = local.name
  vpc_id                = "<ENTER_VPC_ID>"
  subnet_id             = "<ENTER_SUBNET_ID>"
  aws_region            = "<ENTER_AWS_REGION>"
  source_cidr           = ["<ENTER your IP here to access EC2 Image Builder Instances through RDP or SSH>"]
  create_security_group = true
  create_key_pair       = true
  instance_types        = ["c5.large"]
  source_ami_name       = "Windows_Server-2022-English-Core-Base-*"
  ami_name              = "Windows 2022 core AMI"
  ami_description       = "Windows 2022 core AMI provided by AWS"
  recipe_version        = "0.0.1"
  build_component_arn   = [aws_imagebuilder_component.win2022build.arn]
  test_component_arn    = [aws_imagebuilder_component.win2022test.arn]
  s3_bucket_name        = aws_s3_bucket.ec2_image_builder_components.id
  custom_policy_arn     = aws_iam_policy.policy.arn
  platform              = "Windows"
  tags                  = local.tags

  managed_components = [{
    name    = "powershell-windows",
    version = "7.2.10"
    },
    {
      name    = "chocolatey",
      version = "1.0.0"
  }]

  target_account_ids = [
    "<ENTER TARGET AWS ACCOUNT IDS.>"
  ]

  #For Unencrypted AMI
  ami_regions_kms_key = {
    "<ENTER TARGET AWS REGION TO SHARE THE AMI WITH>" = ""
  }

  #or
  #for Encrypt AMI
  #ami_regions_kms_key = {
  #  "<ENTER TARGET AWS REGION TO SHARE THE AMI WITH>" = "<ENTER KMS KEYs TO ENCRYPT AMIs ON THE TARGET REGION>"
  #}


  depends_on = [
    aws_iam_policy.policy,
    aws_imagebuilder_component.win2022build,
    aws_imagebuilder_component.win2022test,
    aws_s3_bucket.ec2_image_builder_components,
    aws_s3_object.upload_scripts
  ]
}

resource "aws_s3_object" "upload_scripts" {
  for_each = fileset("./scripts/", "**/*")

  bucket = aws_s3_bucket.ec2_image_builder_components.id
  key    = "./scripts/${each.value}"
  source = "./scripts/${each.value}"
  etag   = filemd5("./scripts/${each.value}")
  tags   = local.tags
}


resource "aws_imagebuilder_component" "win2022build" {

  name     = "win2022build"
  version  = local.build_version
  platform = "Windows"
  uri      = "s3://${aws_s3_bucket.ec2_image_builder_components.id}/${local.build_file_name}"

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
  etag   = filemd5("${local.build_file_name}")
  tags   = local.tags
}

resource "aws_imagebuilder_component" "win2022test" {

  name     = "win2022test"
  version  = local.test_version
  platform = "Windows"
  uri      = "s3://${aws_s3_bucket.ec2_image_builder_components.id}/${local.test_file_name}"

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
  etag   = filemd5("${local.test_file_name}")
  tags   = local.tags
}

resource "aws_iam_policy" "policy" {

  name        = "custom_policy"
  path        = "/"
  description = "My custom policy"
  policy      = data.aws_iam_policy_document.iam_policy_document.json
}

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
    }
  ]
}
EOF
}


#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "ec2_image_builder_components" {
  bucket = "${local.name}-components"
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
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "ec2_image_builder_components_acl" {
  bucket = aws_s3_bucket.ec2_image_builder_components.id
  acl    = "private"
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