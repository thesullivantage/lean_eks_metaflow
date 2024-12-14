variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "queue_name" {
  description = "The name of the SQS queue"
  type        = string
  default     = "my-queue"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for EKS cluster"
  type        = list(string)
}
