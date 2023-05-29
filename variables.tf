variable "vpc_id" {
  type        = string
  description = "(Required) VPC ID to deploy the EC2 Image Builder Environment."
}

variable "aws_region" {
  type        = string
  description = "(Required) AWS Region to deploy the resources"
}

variable "subnet_id" {
  type        = string
  description = "(Required) Subnet ID to deploy the EC2 Image Builder Environment."
}

variable "name" {
  type        = string
  description = "(Required) Choose a name for the project which will be the prefix for every resource"
}

variable "ami_name" {
  type        = string
  description = "(Required) Choose a name for the AMI"
}

variable "source_ami_name" {
  type        = string
  description = "(Required) Source AMI name, e.g: Windows_Server-2022-English-Core-Base-*"
}

variable "source_ami_owner" {
  type        = string
  description = "(Optional) Owner of the AMI , default: amazon"
  default     = "amazon"
}

variable "ami_description" {
  type        = string
  description = "(Required) Choose a description for the AMI"
}

variable "instance_types" {
  type        = list(string)
  description = <<-EOD
  (Optional) Instance type for the EC2 Image Builder Instances. 
  Will be set by default to c5.large. Please check the AWS Pricing for more information about the instance types.
  EOD
  default     = ["c5.large"]
}

variable "recipe_version" {
  type        = string
  description = "(Required) The semantic version of the image recipe. This version follows the semantic version syntax. e.g.: 0.0.1"
  default     = "0.0.1"
}

variable "s3_bucket_name" {
  type        = string
  description = "(Required) S3 Bucket Name which will store EC2 Image Builder TOE logs and is storing the build/test YAML files"
  default     = ""
}

variable "build_component_arn" {
  type        = list(string)
  description = "(Required) List of ARNs for the Build EC2 Image Builder Build Components"
  default     = []
}

variable "test_component_arn" {
  type        = list(string)
  description = "(Required) List of ARNs for the Build EC2 Image Builder Test Components"
  default     = []
}

variable "tags" {
  description = "(Optional) A map of resource tags to associate with the resource"
  type        = map(string)
  default     = {}
}

variable "target_account_ids" {
  description = "(Optional) A list of target accounts to share the AMI with"
  type        = list(string)
  default     = []
}

variable "ami_regions_kms_key" {
  description = "(Optional) A list of AWS Regions to share the AMI with and also target KMS Key in each region"
  type        = map(string)
  default     = {}
}

variable "source_cidr" {
  type        = list(string)
  description = "(Required) Source CIDR block which will be allowed to RDP or SSH to EC2 Image Builder Instances"
  default     = []
}

variable "attach_custom_policy" {
  type        = bool
  description = "(Required) Attach custom policy to the EC2 Instance Profile, if true, ARN of the custom policy needs to be specified on the variable custom_policy_arn"
  default     = false
}

variable "custom_policy_arn" {
  type        = string
  description = "(Optional) ARN of the custom policy to be attached to the EC2 Instance Profile"
  default     = null
}

variable "schedule_expression" {
  type = list(object({
    pipeline_execution_start_condition = string,
    scheduleExpression                 = string
  }))
  description = <<-EOD
  "(Optional) pipeline_execution_start_condition = The condition configures when the pipeline should trigger a new image build. 
  Valid Values: EXPRESSION_MATCH_ONLY | EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE
  scheduleExpression = The cron expression determines how often EC2 Image Builder evaluates your pipelineExecutionStartCondition.
  e.g.:  "cron(0 0 * * ? *)"
  EOD
  default     = []
}

variable "timeout" {
  type        = string
  description = "(Optional) Number of hours before image time out. Defaults to 2h. "
  default     = "2h"
}

variable "managed_components" {
  type = list(object({
    name    = string,
    version = string
  }))
  description = "(Optional) Specify the name and version of the AWS managed components that are going to be part of the image recipe"
  default     = []
}

variable "platform" {
  type        = string
  description = "(Required) OS: Windows or Linux"

  validation {
    condition     = contains(["Windows", "Linux"], var.platform)
    error_message = "Invalid input, options: \"Windows\", \"Linux\"."
  }
}

variable "instance_metadata_http_put_hop_limit" {
  default     = null
  description = "The number of hops that an instance can traverse to reach its metadata."
  type        = number
}

variable "instance_metadata_http_tokens" {
  default     = "optional"
  description = "(Optional) Whether a signed token is required for instance metadata retrieval requests. Valid values: required, optional."
  type        = string
}

variable "terminate_on_failure" {
  default     = true
  description = "(Optional) Change to false if you want to connect to a builder for debugging after failure"
  type        = bool
}

variable "create_security_group" {
  description = "(Optional) Create security group for EC2 Image Builder instances"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "(Optional) Security group IDs for EC2 Image Builder instances(In case existent Security Group is provided)"
  type        = list(string)
  default     = []
}

variable "instance_key_pair" {
  default     = null
  description = "(Optional) EC2 key pair to add to the default user on the builder(In case existent EC2 Key Pair is provided)"
  type        = string
}