data "aws_caller_identity" "current" {}

# Dynamically fetch subnet information based on the provided subnet IDs
data "aws_subnet" "selected" {
  for_each = toset(var.private_subnet_ids)
  id       = each.key
}

locals {
  # Extract unique AZs from the fetched subnet data
  azs = sort(distinct([for subnet in data.aws_subnet.selected : subnet.availability_zone]))

  tags = {
    env       = var.env
    tf_module = "aws/s3"
  }

  fargate_configurational_values = trimspace(jsonencode({
    computeType = "Fargate"
    # Ensure that we fully utilize the minimum amount of resources that are supplied by
    # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
    # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
    # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
    # compute configuration that most closely matches the sum of vCPU and memory requests in
    # order to ensure pods always have the resources that they need to run.
    resources = {
      limits = {
        cpu = "0.25"
        # We are targetting the smallest Task size of 512Mb, so we subtract 256Mb from the
        # request/limit to ensure we can fit within that task
        memory = "256M"
      }
      requests = {
        cpu = "0.25"
        # We are targetting the smallest Task size of 512Mb, so we subtract 256Mb from the
        # request/limit to ensure we can fit within that task
        memory = "256M"
      }
    }
  }))
}

output "azs" {
  value = local.azs
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "= 19.21.0"

  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  #  cluster_endpoint_private_access      = true
  cluster_additional_security_group_ids   = var.cluster_additional_security_group_ids
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids # var.public_subnet_ids

  enable_irsa = true

  cluster_enabled_log_types = var.cluster_enabled_log_types

  manage_aws_auth_configmap = true

  aws_auth_roles = local.aws_auth_roles
  aws_auth_users = local.aws_auth_users

  cluster_encryption_config = {}

  cluster_timeouts = {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  cluster_addons = {
    vpc-cni = {
      #      configuration_values = local.fargate_configurational_values
      most_recent        = true
      kubernetes_version = var.cluster_version
      resolve_conflicts  = "OVERWRITE"

      timeouts = {
        create = "25m"
        delete = "10m"
      }

      tags = local.tags
    }

    coredns = {
      configuration_values = local.fargate_configurational_values
      most_recent          = true
      kubernetes_version   = var.cluster_version
      resolve_conflicts    = "OVERWRITE"

      timeouts = {
        create = "25m"
        delete = "10m"
      }

      tags = local.tags
    }

    kube-proxy = {
      #      configuration_values = local.fargate_configurational_values
      most_recent        = true
      kubernetes_version = var.cluster_version
      resolve_conflicts  = "OVERWRITE"

      timeouts = {
        create = "25m"
        delete = "10m"
      }

      tags = local.tags
    }
  }

  create_cluster_security_group = true
  create_node_security_group    = true
  node_security_group_name      = "${var.cluster_name}-node-sg"
  node_security_group_tags = merge(
    local.tags,
    { 
      "karpenter.sh/discovery" = var.cluster_name,
      "kubernetes.io/cluster/${var.cluster_name}" = null
    }
  )

  fargate_profiles = merge(
    { for i in range(length(local.azs)) :
      "${var.cluster_name}-kube-system-${element(split("-", local.azs[i]), 2)}" => {
        selectors = [
          { namespace = "kube-system" },
          { namespace = "flux-system" },
          { namespace = "rabbitmq-system" },
          { namespace = "cloudnative-pg" },
          { namespace = "metrics-server" }
        ]
        # We want to create a profile per AZ for high availability
        subnet_ids = [element(var.private_subnet_ids, i)]
      }
    },
    { for i in range(length(local.azs)) :
      "${var.cluster_name}-security-${element(split("-", local.azs[i]), 2)}" => {
        selectors = [
          { namespace = "security" },
          { namespace = "observability" }
        ]
        # We want to create a profile per AZ for high availability
        subnet_ids = [element(var.private_subnet_ids, i)]
      }
    },
    { for i in range(length(local.azs)) :
      "${var.cluster_name}-karpenter-${element(split("-", local.azs[i]), 2)}" => {
        selectors = [
          { namespace = "karpenter" }
        ]
        # We want to create a profile per AZ for high availability
        subnet_ids = [element(var.private_subnet_ids, i)]
      }
    },
  )

  tags = merge(
    local.tags,
    {
      Name                     = var.cluster_name
      "karpenter.sh/discovery" = var.cluster_name
    }
  )
}
