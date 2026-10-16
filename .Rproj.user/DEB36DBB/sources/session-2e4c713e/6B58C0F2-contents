required <- c("shiny", "DT")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
# Optional verified geographic polygons:
# install.packages(c("sf", "leaflet"), repos = "https://cloud.r-project.org")
message("Ready. Open this project and run shiny::runApp().")
