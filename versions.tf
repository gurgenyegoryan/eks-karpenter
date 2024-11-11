terraform {
  required_providers {
    aws        = "= 5.53.0"
    local      = "= 2.5.1"
    null       = "= 3.2.2"
    kubernetes = "= 2.31.0"
    helm       = "= 2.14.0"
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.14.0"
    }
  }
}
