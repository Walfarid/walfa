# Remote state backend — OCI Object Storage (S3-compatible endpoint)
# State is stored in the walfa-tfstate bucket created in Phase 3.
# Access keys come from environment variables (OCI S3 HMAC customer secrets):
#   AWS_ACCESS_KEY_ID     — HMAC key ID
#   AWS_SECRET_ACCESS_KEY — HMAC shared secret
#   AWS_DEFAULT_REGION    — ap-singapore-1

terraform {
  backend "s3" {
    bucket = "walfa-tfstate"
    key    = "prod/terraform.tfstate"
    region = "ap-singapore-1"
    endpoints = {
      s3 = "https://axcrmi3rzxfh.compat.objectstorage.ap-singapore-1.oraclecloud.com"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
