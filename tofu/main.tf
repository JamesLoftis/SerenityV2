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
        uid       = "serenity-sheets"
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
    # Comprehensive financial dashboard optimized for Tiller data structure
    # Uses proper Grafana dashboard schema with robust configuration
    dashboard = {
      id = null
      title = "Serenity Financial Overview"
      uid = "serenity-overview"
      version = 2
      editable = true
      fiscalYearStartMonth = 0
      graphTooltip = 1
      time = { from = "now-90d", to = "now" }
      timepicker = {
        refresh_intervals = ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"]
        time_options = ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d", "90d"]
      }
      refresh = "5m"
      panels = [
        {
          type = "stat"
          title = "Net Worth"
          gridPos = { x=0, y=0, w=6, h=4 }
          id = 1
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "thresholds" }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "yellow", value = 0 },
                  { color = "green", value = 10000 }
                ]
              }
              unit = "currencyUSD"
              decimals = 0
            }
          }
          options = {
            reduceOptions = { 
              calcs = ["lastNotNull"]
              fields = ""
              values = false
            }
            orientation = "auto"
            textMode = "value_and_name"
            colorMode = "background"
            graphMode = "area"
            justifyMode = "auto"
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Balance History!B:B"  # Tiller's Balance History sheet
              cacheDurationSeconds = 300
              valueMapper = "Number"
            }
          ]
        },
        {
          # Monthly Spending
          type = "stat"
          title = "This Month Spending"
          gridPos = { x=6, y=0, w=6, h=4 }
          id = 2
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "thresholds" }
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "yellow", value = 2000 },
                  { color = "red", value = 3000 }
                ]
              }
              unit = "currencyUSD"
              decimals = 0
            }
          }
          options = {
            reduceOptions = { 
              calcs = ["sum"]
              fields = ""
              values = false
            }
            colorMode = "value"
            graphMode = "none"
            textMode = "value_and_name"
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Transactions!E:E"  # Amount column in Transactions
              cacheDurationSeconds = 300
              valueMapper = "Number"
            }
          ]
        },
        {
          # Account Balances
          type = "stat"
          title = "Cash & Checking"
          gridPos = { x=12, y=0, w=6, h=4 }
          id = 3
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic" }
              unit = "currencyUSD"
              decimals = 0
            }
          }
          options = {
            reduceOptions = { 
              calcs = ["lastNotNull"]
              fields = ""
              values = false
            }
            colorMode = "value"
            textMode = "value"
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Accounts!F:F"  # Balance column in Accounts sheet
              cacheDurationSeconds = 300
              valueMapper = "Number"
            }
          ]
        },
        {
          # Quick Health Check
          type = "stat"
          title = "Budget Status"
          gridPos = { x=18, y=0, w=6, h=4 }
          id = 4
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "thresholds" }
              thresholds = {
                mode = "percentage"
                steps = [
                  { color = "green", value = null },
                  { color = "yellow", value = 70 },
                  { color = "red", value = 90 }
                ]
              }
              unit = "percent"
              max = 100
              min = 0
            }
          }
          options = {
            reduceOptions = { 
              calcs = ["mean"]
              fields = ""
              values = false
            }
            colorMode = "background"
            textMode = "value_and_name"
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Monthly Budget!H:H"  # Budget utilization
              cacheDurationSeconds = 300
              valueMapper = "Number"
            }
          ]
        },
        {
          # Net Worth Trend
          type = "timeseries"
          title = "Net Worth Trend (90 Days)"
          gridPos = { x=0, y=4, w=12, h=8 }
          id = 5
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic" }
              custom = {
                axisLabel = "Net Worth"
                axisPlacement = "auto"
                barAlignment = 0
                drawStyle = "line"
                fillOpacity = 20
                gradientMode = "opacity"
                hideFrom = { legend = false, tooltip = false, vis = false }
                lineInterpolation = "smooth"
                lineWidth = 2
                pointSize = 4
                scaleDistribution = { type = "linear" }
                showPoints = "auto"
                spanNulls = false
                stacking = { group = "A", mode = "none" }
                thresholdsStyle = { mode = "off" }
              }
              unit = "currencyUSD"
              decimals = 0
            }
          }
          options = {
            tooltip = { mode = "multi", sort = "desc" }
            legend = { 
              displayMode = "table"
              placement = "bottom"
              calcs = ["lastNotNull", "mean", "max", "min"]
            }
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Balance History!A:B"  # Date and Balance columns
              cacheDurationSeconds = 300
            }
          ]
        },
        {
          # Spending by Category (Current Month)
          type = "piechart"
          title = "Spending by Category (This Month)"
          gridPos = { x=12, y=4, w=12, h=8 }
          id = 6
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic" }
              unit = "currencyUSD"
              decimals = 0
            }
          }
          options = {
            reduceOptions = { 
              calcs = ["sum"]
              fields = ""
              values = false
            }
            pieType = "pie"
            tooltip = { mode = "single" }
            legend = { 
              displayMode = "table"
              placement = "right"
              calcs = ["sum"]
            }
            displayLabels = ["name", "percent"]
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Categories!A:D"  # Category spending data
              cacheDurationSeconds = 300
            }
          ]
        },
        {
          # Recent Transactions Table
          type = "table"
          title = "Recent Transactions (Last 30 Days)"
          gridPos = { x=0, y=12, w=24, h=8 }
          id = 7
          datasource = { 
            type = "marcusolsson-googlesheets-datasource"
            uid = "serenity-sheets"
          }
          fieldConfig = {
            defaults = {
              color = { mode = "thresholds" }
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "transparent", value = null }
                ]
              }
            }
            overrides = [
              {
                matcher = { id = "byName", options = "Amount" }
                properties = [
                  { id = "unit", value = "currencyUSD" },
                  { id = "color", value = { mode = "continuous-GrYlRd" } }
                ]
              },
              {
                matcher = { id = "byName", options = "Date" }
                properties = [
                  { id = "custom.width", value = 100 }
                ]
              }
            ]
          }
          options = {
            showHeader = true
            sortBy = [{ desc = true, displayName = "Date" }]
            footer = {
              show = false
              reducer = ["sum"]
              fields = ""
            }
          }
          targets = [
            {
              refId = "A"
              spreadsheet = var.sheet_id
              range = "Transactions!A:H"  # Full transaction data
              cacheDurationSeconds = 120
            }
          ]
          transformations = [
            {
              id = "sortBy"
              options = { sort = [{ field = "Date", desc = true }] }
            },
            {
              id = "limit"
              options = { limitField = 50 }
            }
          ]
        }
      ],
      schemaVersion = 39
      style = "dark"
      tags = ["serenity", "tiller", "financial", "overview"]
      templating = { 
        list = [
          {
            name = "account_filter"
            type = "query" 
            query = ""
            refresh = 1
            includeAll = true
            allValue = ".*"
            hide = 0
          }
        ]
      }
      timezone = "browser"
      weekStart = ""
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
