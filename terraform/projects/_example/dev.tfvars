# Example project. Copy this folder to terraform/projects/<your-project>/, then switch on the
# services you need. Folders starting with "_" are validated but never planned or applied.

# Resource group (created by Terraform) and region for all resources
resource_group_name = "rg-example-tf-dev"
location            = "westus2"

project_name = "example"
environment  = "dev"
tags = {
  owner      = "your-name"
  costCenter = "your-cost-center"
}

# ---------- Services: switch on only what you need ----------
deploy_app_service     = false
deploy_web_angular_api = true
deploy_function_app    = true
deploy_storage_account = true
enable_monitoring      = true

# ---------- Settings (every attribute is optional; defaults shown) ----------

# Shared Linux plan for the web apps (App Service, Angular client, .NET API)
app_service_plan = {
  sku_name       = "F1" # cheapest; B1 (default) or higher for Always On and production use
  instance_count = 1
}

app_service = {
  runtime_stack   = "dotnet" # dotnet, node, python, java, php
  runtime_version = "8.0"
  app_settings    = {}
}

web_angular_api = {
  client_node_version = "20-lts"
  api_dotnet_version  = "8.0"
  api_app_settings = {
    ASPNETCORE_ENVIRONMENT = "Development"
  }
  api_extra_cors_origins = [
    "http://localhost:4200", # Angular dev server calling the dev API
  ]
}

function_app = {
  runtime_name           = "dotnet-isolated" # dotnet-isolated, node, python, java, powershell
  runtime_version        = "8.0"
  instance_memory_mb     = 2048
  maximum_instance_count = 40
  app_settings           = {}
}

storage_account = {
  replication_type = "LRS"
  containers       = ["uploads"]
  queues           = []
  tables           = []
}
