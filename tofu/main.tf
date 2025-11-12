// tofu/main.tf
terraform {
  required_version = ">= 1.6.0"
}

locals {
  # Option A: secure (private sheet via plugin + service account)
  sheets_datasource_yaml = yamlencode({
    apiVersion = 1
    datasources = [
      {
        name      = "Serenity Sheets"
        type      = "marcusolsson-googlesheets-datasource"
        access    = "proxy"
        isDefault = true
        jsonData  = {
          authenticationType = "jwt"               # service account
          # The plugin expects a JSON key; we reconstruct from env vars
          # If you prefer, mount a real keyfile and set 'credentials' from file.
          jwt = jsonencode({
            type                        = "service_account"
            client_email                = var.gdrive_sa_email
            private_key                 = replace(var.gdrive_sa_private_key, "\\n", "\n")
          })
        }
      }
    ]
  })

  # Option B: simple (public publish-to-web CSV via Infinity). Safer for testing only.
  infinity_datasource_yaml = yamlencode({
    apiVersion = 1
    datasources = [
      {
        name      = "Serenity Infinity"
        type      = "yesoreyeram-infinity-datasource"
        access    = "proxy"
        isDefault = false
      }
    ]
  })

  dashboards_provider_yaml = yamlencode({
    apiVersion = 1
    providers  = [
      {
        name            = "serenity-dashboards"
        orgId           = 1
        type            = "file"
        disableDeletion = false
        updateIntervalSeconds = 10
        options = {
          path = "/etc/grafana/provisioning/dashboards"
        }
      }
    ]
  })

  serenity_dashboard = {
    # minimal, opinionated dashboard with balances + deltas
    # Datasource: "Serenity Sheets" (Google Sheets plugin)
    # Replace the query with your Sheet ID + ranges (see README notes).
    dashboard = {
      id = null
      title = "Serenity Overview"
      uid = "serenity-overview"
      version = 1
      time = { from = "now-30d", to = "now" }
      panels = [
        {
          type = "stat"
          title = "Total Balance"
          gridPos = { x=0,y=0,w=8,h=6 }
          datasource = { type="marcusolsson-googlesheets-datasource", uid = "-100" }
          options = { reduceOptions = { calcs = ["lastNotNull"], values = false }, colorMode="value" }
          targets = [
            {
              refId = "A"
              # Example query: sum on a named range or specific sheet column
              # Plugin uses Google Sheets formulas; here we read a specific range
              spreadsheet = var.sheet_id
              range       = "Balances!B2:B999"
              valueMapper = "Number"
              transformation = "sum"
            }
          ]
        },
        {
          type="timeseries"
          title="Daily Net Change"
          gridPos = { x=8,y=0,w=16,h=6 }
          datasource = { type="marcusolsson-googlesheets-datasource", uid = "-100" }
          fieldConfig = { defaults = { } }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range       = "Transactions!A:C"    # date, amount, category
              # You’ll map date->time, amount->value in the plugin query UI; provisioning keeps it simple.
            }
          ]
        },
        {
          type="table"
          title="Recent Transactions"
          gridPos = { x=0,y=6,w=24,h=10 }
          datasource = { type="marcusolsson-googlesheets-datasource", uid = "-100" }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range       = "Transactions!A:F"
            }
          ]
          options = { }
        }
      ],
      schemaVersion = 39
      style = "dark"
      tags = ["serenity","tiller","v2"]
      templating = { list = [] }
      timezone = ""
    }
    folderId = 0
    overwrite = true
  }
}

# Write provisioning files
resource "local_file" "datasource" {
  filename   = "/out/provisioning/datasources/datasource.yaml"
  content    = local.sheets_datasource_yaml
  depends_on = [null_resource.mkdirs]
}

resource "local_file" "dash_provider" {
  filename   = "/out/provisioning/dashboards/dashboards.yaml"
  content    = local.dashboards_provider_yaml
  depends_on = [null_resource.mkdirs]
}

resource "local_file" "serenity_dash" {
  filename   = "/out/provisioning/dashboards/serenity_overview.json"
  content    = jsonencode(local.serenity_dashboard.dashboard)
  depends_on = [null_resource.mkdirs]
}

# Create directories if missing
resource "null_resource" "mkdirs" {
  provisioner "local-exec" {
    command = "mkdir -p /out/provisioning/datasources /out/provisioning/dashboards"
  }
  triggers = {
    ts = timestamp()
  }
}
