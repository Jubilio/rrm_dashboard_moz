# Production is the default. Empty operational tables indicate sources not yet supplied.
# Use RRM_DATA_MODE=demo explicitly for isolated demonstrations and development.
DATA_MODE <- Sys.getenv("RRM_DATA_MODE", "operational")
APP_TITLE <- "RRM dashboard"
APP_SUBTITLE <- "Cabo Delgado, Mozambique"

# Keep the live reporting workbook outside the public repository. Blank uses the sanitised supplied snapshot.
ACTIVITY_WORKBOOK_PATH <- Sys.getenv('RRM_ACTIVITY_WORKBOOK', '')
