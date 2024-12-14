variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "queue_name" {
  description = "The name of the SQS queue"
  type        = string
  default     = "my-queue"
}
