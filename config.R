# Core data mode is taken from workbook Metadata unless RRM_DATA_MODE is explicitly set.
DATA_MODE <- Sys.getenv("RRM_DATA_MODE", "operational")
APP_TITLE <- "RRM dashboard"
APP_SUBTITLE <- "Cabo Delgado, Mozambique"
# Public address, used for the link preview image (must be absolute for WhatsApp, Teams, LinkedIn).
APP_URL <- Sys.getenv("RRM_APP_URL", "https://jubilio.shinyapps.io/rrm_dashboard/")
APP_DESCRIPTION <- "Alerts, rapid needs assessments, vulnerability screening and reported response for the Rapid Response Mechanism in Cabo Delgado, Mozambique."

# Use the updated local workbook when available; an explicit environment value
# still takes precedence. Blank selects the supplied snapshot.
local_activity_workbook <- 'data/activity_report/MOZ_RRM_Activity_Reporting_Standardised Updated.xlsx'
ACTIVITY_WORKBOOK_PATH <- Sys.getenv('RRM_ACTIVITY_WORKBOOK',
  if (file.exists(local_activity_workbook)) local_activity_workbook else '')

# Consolidated core inputs: read this file when present, otherwise use core CSVs.
INPUT_WORKBOOK_PATH <- Sys.getenv("RRM_INPUT_WORKBOOK", "data/RRM_Dashboard_Input_RNA_populated.xlsx")
