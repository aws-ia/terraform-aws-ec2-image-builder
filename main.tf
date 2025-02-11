# ---------------------------------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_ami" "source_ami" {
  most_recent = true
  owners      = [var.source_ami_owner]
  filter {
    name   = "name"
    values = [var.source_ami_name]
  }
}

data "aws_imagebuilder_components" "managed_components" {
  for_each = {
    for index, mc in var.managed_components :
    mc.name => mc
  }
  owner = "Amazon"

  filter {
    name   = "platform"
    values = [var.platform]
  }

  filter {
    name   = "name"
    values = [each.value.name]
  }

  filter {
    name   = "version"
    values = [each.value.version]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Security Group
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "security_group" {
  count = var.create_security_group ? 1 : 0
  #checkov:skip=CKV2_AWS_5:Security Group is being attached if var create_security_group is true
  name        = "${var.name}-sg"
  description = "Security Group for for the EC2 Image Builder Build Instances"
  vpc_id      = data.aws_vpc.selected.id

  tags = var.tags
}

resource "aws_security_group_rule" "sg_https_ingress" {
  count             = var.create_security_group ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "HTTPS from VPC"
}

resource "aws_security_group_rule" "sg_rdp_ingress" {
  count             = var.create_security_group && length(var.source_cidr) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = var.source_cidr
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "RDP from the source variable CIDR"
}

#tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "sg_internet_egress" {
  count             = var.create_security_group ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "Access to the internet"
}


# ---------------------------------------------------------------------------------------------------------------------
# IAM Role
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "awsserviceroleforimagebuilder" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name               = "${var.name}-role"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "imagebuilder" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "EC2InstanceProfileImageBuilder-${var.name}"
  role = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  count      = var.attach_custom_policy ? 1 : 0
  policy_arn = var.custom_policy_arn
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_role_policy" "aws_policy" {
  name   = "${var.name}-aws-access"
  role   = aws_iam_role.awsserviceroleforimagebuilder.id
  #checkov:skip=CKV_AWS_290:The policy must allow *
  #checkov:skip=CKV_AWS_355:The policy must allow *
  policy = data.aws_iam_policy_document.aws_policy.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "aws_policy" {

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/EC2ImageBuilderDistributionCrossAccountRole"]
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Infrastructure Configuration
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_imagebuilder_infrastructure_configuration" "imagebuilder_infrastructure_configuration" {
  count                 = 1
  instance_profile_name = aws_iam_instance_profile.iam_instance_profile.name
  instance_types        = var.instance_types
  key_pair              = var.instance_key_pair

  name               = "${var.name}-infrastructure-configuration"
  security_group_ids = var.create_security_group ? [aws_security_group.security_group[count.index].id] : var.security_group_ids
  subnet_id          = var.subnet_id

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  terminate_instance_on_failure = var.terminate_on_failure
  resource_tags                 = var.tags
  tags                          = var.tags

  logging {
    s3_logs {
      s3_bucket_name = var.s3_bucket_name
      s3_key_prefix  = "logs"
    }
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_image" "imagebuilder_image" {
  count                            = 1
  image_recipe_arn                 = aws_imagebuilder_image_recipe.imagebuilder_image_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imagebuilder_infrastructure_configuration[count.index].arn
  distribution_configuration_arn   = try(aws_imagebuilder_distribution_configuration.imagebuilder_distribution_configuration[count.index].arn, null)

  image_tests_configuration {
    image_tests_enabled = true
  }
  tags = var.tags

  timeouts {
    create = var.timeout
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image Pipeline
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_image_pipeline" "imagebuilder_image_pipeline" {
  count                            = 1
  image_recipe_arn                 = aws_imagebuilder_image_recipe.imagebuilder_image_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imagebuilder_infrastructure_configuration[count.index].arn
  distribution_configuration_arn   = try(aws_imagebuilder_distribution_configuration.imagebuilder_distribution_configuration[count.index].arn, null)
  dynamic "schedule" {
    for_each = try(var.schedule_expression, tomap({}))
    content {
      schedule_expression                = schedule.key
      pipeline_execution_start_condition = schedule.value
    }
  }
  name = "${var.name}-pipeline"
  tags = var.tags
}


# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image Recipe
# ---------------------------------------------------------------------------------------------------------------------



resource "aws_imagebuilder_image_recipe" "imagebuilder_image_recipe" {
  name         = "${var.name}-image-recipe"
  parent_image = data.aws_ami.source_ami.id
  version      = var.recipe_version
  
  # it seems there is a bug on checkov for check CKV_AWS_200, even supressing it doesn't help, had to add the below block_device_mapping to pass
  block_device_mapping {
    device_name = "/dev/xvdb"

    ebs {
      delete_on_termination = true
      volume_size           = var.recipe_volume_size
      volume_type           = var.recipe_volume_type
      encrypted             = true
      kms_key_id            = var.imagebuilder_image_recipe_kms_key_arn
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  dynamic "component" {
    for_each = {
      for key, value in data.aws_imagebuilder_components.managed_components : key => value.arns
    }
    content {
      component_arn = tolist(component.value)[0]
    }
  }

  dynamic "component" {
    for_each = var.build_component_arn
    content {
      component_arn = component.value
      parameter {
        name  = "S3BucketName"
        value = var.s3_bucket_name
      }
    }
  }

  dynamic "component" {
    for_each = var.test_component_arn
    content {
      component_arn = component.value
      parameter {
        name  = "S3BucketName"
        value = var.s3_bucket_name
      }
    }
  }

  tags = var.tags

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Distribution Configuration
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_distribution_configuration" "imagebuilder_distribution_configuration" {
  count = length(var.ami_regions_kms_key) > 0 ? 1 : 0 #need to add a count due the error "At least 1 "distribution" blocks are required" when ami_regions_kms_key = {}
  name  = "${var.name}-distribution"

  dynamic "distribution" {
    for_each = var.ami_regions_kms_key # for each region we need to have a new distribution setting
    content {
      region = distribution.key
      ami_distribution_configuration {
        name               = "${var.ami_name}-{{ imagebuilder:buildDate }}"
        description        = var.ami_description
        target_account_ids = var.target_account_ids
        launch_permission {
          user_ids = var.target_account_ids
        }

        ami_tags = var.tags
        # AMI Should be encrypted by different KMS key according to the region, however if no KMS Key is provided the image will not be encrypted
        kms_key_id = length(distribution.value) > 0 ? distribution.value : null

      }
    }

  }
  tags = var.tags
}

