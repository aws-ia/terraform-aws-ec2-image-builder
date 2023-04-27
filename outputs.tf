output "ami" {
  value       = try(element(tolist(aws_imagebuilder_image.imagebuilder_image[0].output_resources[0].amis), 0).image, "")
  description = "AMI created by Terraform"
}