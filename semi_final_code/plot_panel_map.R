library(ggplot2)
library(dplyr)

plot_panel_map <- function(panel_data, nrows = 10, total_panels = 100, value_col = "avg_power", title = "Solar Panel Performance") {
  ncols <- ceiling(total_panels / nrows)
  panel_positions <- expand.grid(
    Row = seq_len(nrows),
    Col = seq_len(ncols)
  ) %>%
    mutate(panel_id = sprintf("P%03d", seq_len(n())))
  
  df <- left_join(panel_positions, panel_data, by = "panel_id") %>%
    mutate(value = pmin(pmax(!!sym(value_col), 0), 1))  # clamp 0–1
  
  ggplot(df, aes(x = Col, y = Row, fill = value)) +
    geom_tile(color = "white", width = 0.9, height = 0.9, linewidth = 0.5) +
    scale_fill_gradientn(colors = c("red", "yellow", "green"), limits = c(0,1), name = "Performance") +
    coord_fixed() +
    scale_y_reverse() +
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal(base_size = 14) +
    theme(
      panel.grid = element_blank(),
      plot.background = element_rect(fill = "white", color = NA),
      legend.position = "right"
    )
}
