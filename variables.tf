variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "env" {
  type    = string
  default = null
}

variable "cluster_name" {
  type    = string
  default = null
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "public_subnet_ids" {
  type    = list(string)
  default = null
}

variable "private_subnet_ids" {
  type    = list(string)
  default = null
}

variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "cluster_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "cluster_security_group_additional_rules" {
  description = "List of additional security group rules to add to the cluster security group created. Set `source_node_security_group = true` inside rules to set the `node_security_group` as source"
  type        = any
  default     = {}
}

variable "cluster_enabled_log_types" {
  type    = list(string)
  default = ["audit", "api", "authenticator"]
}

# 0.32+ !!!

# https://karpenter.sh/v0.32/concepts/nodeclasses/

variable "karpenter_nodeclass_arm64_name" {
  type    = string
  default = "bottlerocket-arm64"
}

variable "karpenter_nodeclass_amd64_name" {
  type    = string
  default = "al2-amd64"
}

variable "karpenter_nodepool_cpu_limit" {
  type    = string
  default = "1000"
}

variable "karpenter_nodepool_memory_limit" {
  type    = string
  default = "1000Gi"
}

variable "karpenter_nodeclass_ebs_size" {
  type    = string
  default = "100Gi"
}

variable "karpenter_nodeclass_ebs_type" {
  type    = string
  default = "gp2"
}

variable "karpenter_nodeclass_ebs_delete_on_termination" {
  type    = string
  default = "true"
}

# https://karpenter.sh/v0.32/concepts/nodepools/

variable "karpenter_nodepool_arm64_name" {
  type    = string
  default = "arm64"
}

variable "karpenter_nodepool_amd64_name" {
  type    = string
  default = "amd64"
}

variable "karpenter_nodepool_arm64_capacity_types" {
  type    = string
  default = "spot on-demand"
}

variable "karpenter_nodepool_amd64_capacity_types" {
  type    = string
  default = "spot on-demand"
}

variable "karpenter_nodepool_disruption_consolidation_policy" {
  type    = string
  default = "WhenUnderutilized"
}

variable "karpenter_nodepool_disruption_consolidate_after" {
  type    = string
  default = "30s"
}

variable "karpenter_nodepool_disruption_expire_after" {
  type    = string
  default = "720h"
}

variable "karpenter_nodepool_arm64_weight" {
  type    = number
  default = 50 # a higher weight value makes this provisioner preferred
}

variable "karpenter_nodepool_amd64_weight" {
  type    = number
  default = 40
}

variable "aws_sso_developer_role_names" {
  description = "List of role name parts to include in the IAM roles data source for AWS SSO developer"
  type        = list(string)
  default     = []
}

variable "aws_admin_users" {
  description = "List of users with admin access"
  type        = list(string)
  default     = []
}