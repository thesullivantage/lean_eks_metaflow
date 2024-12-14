
locals {
  resource_prefix = "metaflow"
  resource_suffix = random_string.suffix.result
  tags = {
    "managedBy"   = "terraform"
    "application" = "metaflow-eks-example"
  }
  # cluster_name = "mf-${local.resource_suffix}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.23.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.24"
  subnets         = var.private_subnets
  enable_irsa     = true
  tags            = local.tags

  vpc_id = var.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }


  node_groups = {
    system = {  // Renamed from 'main' to 'system'
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1
      instance_types   = ["t3.medium"]  // Downsized from m5.2xlarge
      
      labels = {
        "node-role.kubernetes.io/system" = "true"
      }
      
      taints = {
        # gives this node pool as belonging to system, prevents scheduling
        dedicated = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  workers_additional_policies = [
    # just a default node role 
    aws_iam_policy.default_node.arn
  ]
}


resource "aws_iam_policy" "default_node" {
  name_prefix = "${var.cluster_name}-default"
  description = "Default policy for cluster ${module.eks.cluster_id}"
  policy      = data.aws_iam_policy_document.default_node.json
}

data "aws_iam_policy_document" "default_node" {
  statement {
    sid    = "S3"
    effect = "Allow"

    actions = [
      "s3:*",
      "kms:*",
    ]

    resources = ["*"]
  }
}

# resource "aws_iam_policy" "cluster_autoscaler" {
#   name_prefix = "cluster-autoscaler"
#   description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_id}"
#   policy      = data.aws_iam_policy_document.cluster_autoscaler.json
# }

# data "aws_iam_policy_document" "cluster_autoscaler" {
#   statement {
#     sid    = "clusterAutoscalerAll"
#     effect = "Allow"

#     actions = [
#       "autoscaling:DescribeAutoScalingGroups",
#       "autoscaling:DescribeAutoScalingInstances",
#       "autoscaling:DescribeLaunchConfigurations",
#       "autoscaling:DescribeTags",
#       "ec2:DescribeLaunchTemplateVersions",
#     ]

#     resources = ["*"]
#   }

#   statement {
#     sid    = "clusterAutoscalerOwn"
#     effect = "Allow"

#     actions = [
#       "autoscaling:SetDesiredCapacity",
#       "autoscaling:TerminateInstanceInAutoScalingGroup",
#       "autoscaling:UpdateAutoScalingGroup",
#     ]

#     resources = ["*"]

#     condition {
#       test     = "StringEquals"
#       variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_id}"
#       values   = ["owned"]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
#       values   = ["true"]
#     }
#   }
# }


data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = data.aws_eks_cluster.cluster.endpoint
}

output "cluster_ca_certificate" {
  value = data.aws_eks_cluster.cluster.certificate_authority.0.data
}

output "cluster_auth_token" {
  value = data.aws_eks_cluster_auth.cluster.token
}