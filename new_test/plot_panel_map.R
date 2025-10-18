library(ggplot2)
library(dplyr)

# -------------------------------------------------------------
# plot_panel_map():
#   panel_data ..... Data frame with columns panel_id, Shading, Degradation
#   nrows .......... Number of rows in the grid (default 10)
#   total_panels ... Total number of panels (default 100)
#   aspect_ratio ... Width/height ratio for visualization
# -------------------------------------------------------------
plot_panel_map <- function(panel_data, nrows = 10, total_panels = 100, aspect_ratio = 2) {
  
  # --- 1) Compute number of columns
  ncols <- ceiling(total_panels / nrows)
  
  # --- 2) Grid positions
  panel_positions <- expand.grid(
    Row = seq_len(nrows),
    Col = seq_len(ncols)
  ) %>%
    mutate(panel_id = sprintf("P%03d", seq_len(n())))
  
  # --- 3) Merge with panel data
  df <- left_join(panel_positions, panel_data, by = "panel_id") %>%
    mutate(
      Degradation = ifelse(is.na(Degradation), 0, Degradation),
      Shading     = ifelse(is.na(Shading), 0, Shading)
    )
  
  # --- 4) Color logic
  # Degradation: green → yellow → red (bad)
  # Shading: blueish grey → black (dark)
  df <- df %>%
    mutate(
      combined_severity = pmax(Degradation, Shading),
      condition = case_when(
        Shading > Degradation ~ "Shading",
        Degradation > Shading ~ "Degrading",
        TRUE ~ "Functional"
      )
    )
  
  # Assign blended color palette
  df <- df %>%
    mutate(
      fill_color = case_when(
        condition == "Shading" ~ rgb(0.4 - 0.4 * Shading, 0.4 - 0.4 * Shading, 0.5 - 0.5 * Shading),
        condition == "Degrading" ~ rgb(1, 1 - Degradation, 0),
        TRUE ~ rgb(0.8, 1, 0.8)
      )
    )
  
  # --- 5) Plot layout
  ggplot(df, aes(x = Col, y = Row)) +
    geom_tile(
      aes(fill = fill_color),
      color = "white",
      width = 0.9,
      height = 0.9,
      linewidth = 0.5
    ) +
    scale_fill_identity() +
    scale_y_reverse() +
    coord_fixed(ratio = 1 / aspect_ratio) +
    theme_minimal(base_size = 14) +
    theme(
      axis.text = element_blank(),
      axis.title = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.background = element_rect(fill = "white", color = NA)
    ) +
    labs(
      title = "Solar Panel Condition Map",
      subtitle = "Green = Healthy | Yellow/Red = Degradation | Gray = Shading"
    )
}
