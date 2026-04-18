# Configure remote state before shared use.
# OCI Object Storage is the intended target for this stack.
#
# Example using the S3-compatible backend:
# terraform {
#   backend "s3" {
#     bucket                      = "oracle-tf-state"
#     key                         = "infra-free-tier/terraform.tfstate"
#     region                      = "eu-frankfurt-1"
#     endpoint                    = "https://<namespace>.compat.objectstorage.<region>.oraclecloud.com"
#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_requesting_account_id  = true
#     use_path_style              = true
#   }
# }
