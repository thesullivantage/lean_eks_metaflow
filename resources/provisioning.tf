provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca_certificate)
    token                  = data.terraform_remote_state.eks.outputs.cluster_auth_token
  }
}

resource "aws_cloudformation_stack" "karpenter" {
  name          = "Karpenter-${data.terraform_remote_state.eks.outputs.cluster_id}"
  template_body = file("${path.module}/aux_resources/karpenter_cloudformation.yaml")

  parameters = {
    ClusterName = var.cluster_name
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]
}

resource "aws_cloudformation_stack" "sqs_queue" {
  name          = "SQSQueue-${data.terraform_remote_state.eks.outputs.cluster_id}"
  template_body = file("${path.module}/aux_resources/sqs_queue_cloudformation.yaml")

  parameters = {
    QueueName = var.queue_name
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"

  depends_on = [module.eks]
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  namespace  = "karpenter"

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_id
  }

  set {
    name  = "clusterEndpoint"
    value = data.terraform_remote_state.eks.outputs.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_cloudformation_stack.karpenter.outputs["KarpenterNodeInstanceProfile"]
  }

  set {
    # MARK DEV: change to EKS cluster ID-based
    name  = "settings.aws.interruptionQueueName"
    value = var.cluster_name
  }

  depends_on = [module.eks, aws_cloudformation_stack.karpenter]
}

resource "aws_iam_role" "karpenter_controller" {
  name = "Karpenter-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy.json
}

data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "kubernetes_manifest" "karpenter_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "NotIn"
              values   = ["spot"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["t3.small", "t3.medium", "m5.large", "m5.xlarge"]
            }
          ]
          nodeClassRef = {
            name = "default"
          }
        }
      }
      limits = {
        cpu = 1000
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "argo_scaled_object" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "argo-workflows-scaledobject"
      namespace = "argo"
    }
    spec = {
      scaleTargetRef = {
        name = "argo-workflows"
      }
      minReplicaCount = 1
      maxReplicaCount = 5
      triggers = [
        {
          type     = "aws-sqs-queue"
          metadata = {
            queueURL    = aws_cloudformation_stack.sqs_queue.outputs["QueueURL"]
            queueLength = "5"
            awsRegion   = "us-west-1"
          }
        }
      ]
    }
  }

  depends_on = [helm_release.keda, aws_cloudformation_stack.sqs_queue]
}