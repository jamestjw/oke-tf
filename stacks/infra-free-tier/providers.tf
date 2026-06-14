provider "oci" {
  region              = var.region
  config_file_profile = var.oci_config_profile
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
