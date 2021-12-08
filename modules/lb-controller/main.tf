## kubernetes aws-load-balancer-controller

locals {
  namespace      = lookup(var.helm, "namespace", "kube-system")
  serviceaccount = lookup(var.helm, "serviceaccount", "aws-load-balancer-controller")
}

module "irsa" {
  source         = "../iam-role-for-serviceaccount"
  count          = var.enabled ? 1 : 0
  name           = join("-", ["irsa", local.name])
  namespace      = local.namespace
  serviceaccount = local.serviceaccount
  oidc_url       = var.oidc.url
  oidc_arn       = var.oidc.arn
  policy_arns    = [aws_iam_policy.lbc.0.arn, "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  tags           = var.tags
}

data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  count       = var.enabled ? 1 : 0
  name        = local.name
  description = format("Allow aws-load-balancer-controller to manage AWS resources")
  path        = "/"
  policy      = data.http.iam_policy.body
}

resource "helm_release" "lbc" {
  count           = var.enabled ? 1 : 0
  name            = lookup(var.helm, "name", "aws-load-balancer-controller")
  chart           = lookup(var.helm, "chart", "aws-load-balancer-controller")
  version         = lookup(var.helm, "version", null)
  repository      = lookup(var.helm, "repository", "https://aws.github.io/eks-charts")
  namespace       = local.namespace
  cleanup_on_fail = lookup(var.helm, "cleanup_on_fail", true)

  dynamic "set" {
    for_each = {
      "clusterName"                                               = var.cluster_name
      "serviceAccount.name"                                       = local.serviceaccount
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.irsa[0].arn[0]
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}

# install the TargetGroupBinding CRDs
data "kustomization" "crd" {
  path = "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
}

resource "kustomization_resource" "crd" {
  for_each = data.kustomization.crd.ids
  manifest = data.kustomization.crd.manifests[each.value]
}