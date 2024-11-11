# This data source can only be used in the us-east-1 region.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecrpublic_authorization_token
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}

locals {
  karpenter_namespace = "karpenter"
}

# TODO: narrow down permissions
# https://aws.amazon.com/ru/blogs/containers/karpenter-graduates-to-beta/
#
resource "aws_iam_policy" "karpenter_additional_policy" {
  name        = "${var.cluster_name}-karpenter-additional-policy"
  description = "Policy for Karpenter EC2 permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:*"
        ]
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:ListRoles",
          "iam:ListInstanceProfiles"
        ]
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "= 19.21.0"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AdditionalPolicy             = aws_iam_policy.karpenter_additional_policy.arn
  }

  iam_role_additional_policies = {
    AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  }

  tags = local.tags
}

resource "helm_release" "karpenter" {
  namespace        = local.karpenter_namespace
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.33.1"

  depends_on = [module.eks.fargate_profiles, module.karpenter]

  #  lifecycle {
  #    ignore_changes = [repository_password]
  #  }

  set {
    name  = "controller.image.tag"
    value = "v0.33.1"
  }

  set {
    name  = "replicas"
    value = 2
  }

  set {
    name  = "logLevel"
    value = "debug"
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = 1
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = 1
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }
}

# 0.32+ !!!
# https://karpenter.sh/v0.32/concepts/nodepools/
data "archive_file" "karpenter-nodepools_helm_dir_checksum" {
  type        = "zip"
  source_dir  = "${path.module}/templates/karpenter-nodepools"
  output_path = "/tmp/karpenter-nodepools_helm_dir_checksum.zip"
}

resource "helm_release" "karpenter-nodepools" {
  name             = "karpenter-nodepools"
  chart            = "./templates/karpenter-nodepools"
  namespace        = local.karpenter_namespace
  create_namespace = false
  cleanup_on_fail  = true

  set {
    name  = "helm_dir_hash"
    value = data.archive_file.karpenter-nodepools_helm_dir_checksum.output_md5
  }

  values = [
    templatefile("${path.module}/templates/karpenter-nodepools/values.yaml",
      {
        karpenter_nodepool_arm64_name = var.karpenter_nodepool_arm64_name
        karpenter_nodepool_amd64_name = var.karpenter_nodepool_amd64_name

        karpenter_nodeclass_arm64_name = var.karpenter_nodeclass_arm64_name
        karpenter_nodeclass_amd64_name = var.karpenter_nodeclass_amd64_name

        karpenter_nodepool_arm64_capacity_types = var.karpenter_nodepool_arm64_capacity_types
        karpenter_nodepool_amd64_capacity_types = var.karpenter_nodepool_amd64_capacity_types

        karpenter_nodepool_disruption_consolidation_policy = var.karpenter_nodepool_disruption_consolidation_policy
        karpenter_nodepool_disruption_consolidate_after    = var.karpenter_nodepool_disruption_consolidate_after
        karpenter_nodepool_disruption_expire_after         = var.karpenter_nodepool_disruption_expire_after

        karpenter_nodepool_cpu_limit    = var.karpenter_nodepool_cpu_limit
        karpenter_nodepool_memory_limit = var.karpenter_nodepool_memory_limit

        karpenter_nodepool_arm64_weight = var.karpenter_nodepool_arm64_weight
        karpenter_nodepool_amd64_weight = var.karpenter_nodepool_amd64_weight
      }
    )
  ]

  depends_on = [helm_release.karpenter]
}

# https://karpenter.sh/v0.32/concepts/nodeclasses/

data "archive_file" "karpenter-nodeclasses_helm_dir_checksum" {
  type        = "zip"
  source_dir  = "${path.module}/templates/karpenter-nodepools"
  output_path = "/tmp/karpenter-nodeclasses_helm_dir_checksum.zip"
}

resource "helm_release" "karpenter-nodeclasses" {
  name             = "karpenter-nodeclasses"
  chart            = "./templates/karpenter-nodeclasses"
  namespace        = local.karpenter_namespace
  create_namespace = false
  cleanup_on_fail  = true

  set {
    name  = "helm_dir_hash"
    value = data.archive_file.karpenter-nodeclasses_helm_dir_checksum.output_md5
  }

  values = [
    templatefile("${path.module}/templates/karpenter-nodeclasses/values.yaml",
      {
        env                                           = var.env
        cluster_name                                  = var.cluster_name
        karpenter_instance_profile                    = module.karpenter.instance_profile_name
        karpenter_nodeclass_arm64_name                = var.karpenter_nodeclass_arm64_name
        karpenter_nodeclass_amd64_name                = var.karpenter_nodeclass_amd64_name
        karpenter_nodeclass_ebs_size                  = var.karpenter_nodeclass_ebs_size
        karpenter_nodeclass_ebs_type                  = var.karpenter_nodeclass_ebs_type
        karpenter_nodeclass_ebs_delete_on_termination = var.karpenter_nodeclass_ebs_delete_on_termination
      }
    )
  ]

  depends_on = [helm_release.karpenter]
}
