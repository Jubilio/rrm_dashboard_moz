# Core data mode is taken from workbook Metadata unless RRM_DATA_MODE is explicitly set.
DATA_MODE <- Sys.getenv("RRM_DATA_MODE", "operational")
APP_TITLE <- "RRM dashboard"
APP_SUBTITLE <- "Cabo Delgado, Mozambique"

# Keep the live reporting workbook outside the public repository. Blank uses the sanitised supplied snapshot.
ACTIVITY_WORKBOOK_PATH <- Sys.getenv('RRM_ACTIVITY_WORKBOOK', '')

# Consolidated core inputs: read this file when present, otherwise use core CSVs.
INPUT_WORKBOOK_PATH <- Sys.getenv("RRM_INPUT_WORKBOOK", "data/RRM_Dashboard_Input_RNA_populated.xlsx")
