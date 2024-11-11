module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "= 5.39.1"

  role_name                  = "${var.cluster_name}-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "helm_release" "external-dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  version          = "8.0.0"
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa.iam_role_arn
  }

  set {
    name  = "policy"
    value = "sync" # allows external-dns to delete records if needed
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  depends_on = [module.eks.fargate_profiles]
}
