# The reference layout starts with clearly labelled fictional core records.
# Set RRM_DATA_MODE=operational when approved core inputs are ready.
DATA_MODE <- Sys.getenv("RRM_DATA_MODE", "demo")
APP_TITLE <- "RRM dashboard"
APP_SUBTITLE <- "Cabo Delgado, Mozambique"

# Keep the live reporting workbook outside the public repository. Blank uses the sanitised supplied snapshot.
ACTIVITY_WORKBOOK_PATH <- Sys.getenv('RRM_ACTIVITY_WORKBOOK', '')
