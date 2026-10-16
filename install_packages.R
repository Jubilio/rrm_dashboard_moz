required <- c("shiny", "DT", "readxl")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
# The supplied GeoJSON map uses locally bundled Leaflet JS; no sf/leaflet R package is needed.
message("Ready. Open this project and run shiny::runApp().")
