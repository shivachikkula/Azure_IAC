# Example production settings for the same project. Merging a change to a prod file
# applies it with the "prod" GitHub environment (add required reviewers there for approval).

resource_group_name = "rg-example-tf-prod"
location            = "westus2"

project_name = "example"
environment  = "prod"
tags = {
  owner      = "your-name"
  costCenter = "your-cost-center"
}

deploy_app_service     = false
deploy_web_angular_api = true
deploy_function_app    = true
deploy_storage_account = true
enable_monitoring      = true

app_service_plan = {
  sku_name       = "P0v3"
  instance_count = 2
}

web_angular_api = {
  api_dotnet_version    = "8.0"
  api_health_check_path = "/health"
  api_app_settings = {
    ASPNETCORE_ENVIRONMENT = "Production"
  }
}

function_app = {
  runtime_name           = "dotnet-isolated"
  runtime_version        = "8.0"
  maximum_instance_count = 100
}

storage_account = {
  replication_type           = "ZRS"
  soft_delete_retention_days = 30
  versioning_enabled         = true
  containers                 = ["uploads"]
}
