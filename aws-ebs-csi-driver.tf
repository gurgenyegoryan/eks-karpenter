module "aws_ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "= 5.39.1"

  role_name             = "${var.cluster_name}-aws-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "helm_release" "aws-ebs-csi-driver" {
  name            = "aws-ebs-csi-driver"
  chart           = "aws-ebs-csi-driver"
  repository      = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  namespace       = "kube-system"
  version         = "2.32.0"
  cleanup_on_fail = true

  values = [
    templatefile("${path.module}/templates/aws-ebs-csi-driver/values.yaml",
      {
        aws_ebs_csi_driver_role_arn = module.aws_ebs_csi_driver_irsa.iam_role_arn
        azs                         = "\"${join("\", \"", local.azs)}\""
      }
    )
  ]

  depends_on = [module.eks.fargate_profiles]
}
