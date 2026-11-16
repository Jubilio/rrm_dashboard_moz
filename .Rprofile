# Use project-local packages when available (for example, the local Shiny install).
if (dir.exists('.r-library')) {
  .libPaths(c(utils::shortPathName(normalizePath('.r-library')), .libPaths()))
}
