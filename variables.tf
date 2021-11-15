variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "purpose_tag" {
  description = "Purpose Name"
  type        = string
}

variable "owner_tag" {
  description = "Owner Name"
  type        = string
}

variable "s3_logs_bucket_name" {
  description = "Logs Bucket Name (lowercase only, no spaces)"
  type        = string
}

variable "s3_logs_folder" {
  description = "Logs folder: 'folder0/folder2/log_folder' or 'log_folder'"
  type        = string
}

variable "public_subnets_ids" {
  description = "Public Subnet Ids"
  type        = list(string)
}

variable "private_subnets_ids" {
  description = "Private Subnet Ids"
  type        = list(string)
}

variable "available_zone_names" {
  description = "AZ Names"
  type        = list(string)
}

variable "instance_count" {
  description = "EC2 Instance count"
  type        = number
}

variable "instance_type_db" {
  description = "DB EC2 Instance Type"
  type        = string
}

variable "instance_type_web" {
  description = "Web EC2 Instance Type"
  type        = string
}

variable "private_key_path" {
  default = "C:\\Downloads\\OpsSchool\\Private-Keys\\ec2-key-pair.pem"
}

variable "key_name" {
  default = "ec2-key-pair"
}
