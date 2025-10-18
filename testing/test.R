library(ggplot2)
library(dplyr)
library(scales)


source("plot_panel_map.R")
source("statsdata.R")
source("panel_classification.R")


hourly_stats_array("solar_data_degraded.csv")

classify_panels("solar_data_degraded.csv", "stats_data.csv")



panel_sev <- classify_panels("solar_data_degraded.csv", "stats_data.csv")
plot_panel_map(panel_sev, 10, 100)

