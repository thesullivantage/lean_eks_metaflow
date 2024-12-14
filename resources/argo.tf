provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca_certificate)
  token                  = data.terraform_remote_state.eks.outputs.cluster_auth_token
  load_config_file       = false
}

resource "kubernetes_namespace" "argo" {
  metadata {
    name = "argo"
  }
}

resource "kubernetes_default_service_account" "default" {
  metadata {
    namespace = kubernetes_namespace.argo.metadata[0].name
  }
}

data "aws_region" "current" {}

locals {
  argo_values = {
    "server" = {
      "extraArgs" = ["--auth-mode=server"]
    }
    "workflow" = {
      "serviceAccount" = {
        "create" = true
      }
    }
    "controller" = {
      "containerRuntimeExecutor" = "emissary"
      "affinity" = {
        "nodeAffinity" = {
          "requiredDuringSchedulingIgnoredDuringExecution" = {
            "nodeSelectorTerms" = [
              {
                "matchExpressions" = [
                  {
                    "key"      = "kubernetes.io/instance-type"
                    "operator" = "In"
                    "values"   = ["t3.small", "t3.medium", "m5.large", "m5.xlarge"]
                  }
                ]
              }
            ]
          }
        }
      }
      "tolerations" = [
        {
          "key"      = "argo-workflows"
          "operator" = "Equal"
          "value"    = "true"
          "effect"   = "NoSchedule"
        }
      ]
    }
    "useDefaultArtifactRepo" = true
    "useStaticCredentials"   = false
    "artifactRepository" = {
      "s3" = {
        "bucket"      = module.metaflow-datastore.s3_bucket_name
        "keyFormat"   = "argo-artifacts/{{workflow.creationTimestamp.Y}}/{{workflow.creationTimestamp.m}}/{{workflow.creationTimestamp.d}}/{{workflow.name}}/{{pod.name}}"
        "region"      = data.aws_region.current.name
        "endpoint"    = "s3.amazonaws.com"
        "useSDKCreds" = true
        "insecure"    = false
      }
    }
  }
}



resource "helm_release" "argo" {
  name = "argo"

  depends_on = [module.eks]

  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-workflows"
  namespace    = kubernetes_namespace.argo.metadata[0].name
  force_update = true

  values = [
    yamlencode(local.argo_values)
  ]
}
