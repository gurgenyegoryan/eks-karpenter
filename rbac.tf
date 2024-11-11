data "aws_iam_roles" "aws_sso_admin" {
  name_regex = "AWSReservedSSO_AdministratorAccess_.*"
}

# data "aws_iam_roles" "aws_sso_developer" {
#   name_regex = "AWSReservedSSO_(${join("|", var.aws_sso_developer_role_names)})_.*"
# }

output "aws_sso_admin_role_arn" {
  value = [
    for parts in [for arn in data.aws_iam_roles.aws_sso_admin.arns : split("/", arn)] :
    format("%s/%s", parts[0], element(parts, length(parts) - 1))
  ]
}

# output "aws_sso_developer_role_arn" {
#   value = [
#     for parts in [for arn in data.aws_iam_roles.aws_sso_developer.arns : split("/", arn)] :
#     format("%s/%s", parts[0], element(parts, length(parts) - 1))
#   ]
# }

locals {
  aws_sso_admin_role_arns = [
    for parts in [for arn in data.aws_iam_roles.aws_sso_admin.arns : split("/", arn)] :
    format("%s/%s", parts[0], element(parts, length(parts) - 1))
  ]

  # aws_sso_developer_role_arns = [
  #   for parts in [for arn in data.aws_iam_roles.aws_sso_developer.arns : split("/", arn)] :
  #   format("%s/%s", parts[0], element(parts, length(parts) - 1))
  # ]

  aws_auth_roles = concat(
    [
      {
        rolearn  = module.karpenter.role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:nodes", "system:bootstrappers"]
      },
      {
        rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/"
        username = "{{SessionName}}"
        groups   = ["system:masters"]
      },
    ],
    [for role in local.aws_sso_admin_role_arns :
      {
        rolearn  = role
        username = "{{SessionName}}"
        groups   = ["system:masters"]
      }
    ],
    # [for role in local.aws_sso_developer_role_arns :
    #   {
    #     rolearn  = role
    #     username = "{{SessionName}}"
    #     groups   = ["developer-role"]
    #   }
    # ],
  )

  aws_auth_users = concat(
    [for user in var.aws_admin_users :
             {
               userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
               username = user
               groups   = ["system:masters"]
             }
    ],
    [
             {
               userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/iac"
               username = "iac"
               groups   = ["system:masters"]
             },
      #        {
      #          userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/user1"
      #          username = "user1"
      #          groups   = ["developer-role"]
      #        },
    ]
  )

}
