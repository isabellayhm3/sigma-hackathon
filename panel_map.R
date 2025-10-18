library(ggplot2)
library(dplyr)

plot_panel_map <- function(panel_data, nrows, total_panels, aspect_ratio = 2) {
  # Number of columns
  ncols <- ceiling(total_panels / nrows)
  
  # Grid positions
  panel_positions <- expand.grid(
    Row = seq_len(nrows),
    Col = seq_len(ncols)
  ) %>%
    mutate(PanelID = sprintf("P%03d", seq_len(n())))
  
  # Merge data
  df <- left_join(panel_positions, panel_data, by = "PanelID") %>%
    mutate(
      Degradation = ifelse(is.na(Degradation), 0, Degradation),
      Shading = ifelse(is.na(Shading), 0, Shading)
    )
  
  # Degradation gradient: green → yellow → red
  deg_colors <- colorRamp(c("green", "yellow", "red")) # returns function
  
  # Shading color: grey → black
  shade_colors <- colorRamp(c(rgb(63/255, 94/255, 122/255), "black"))
  
  # Compute blended color
  df <- df %>%
    rowwise() %>%
    mutate(
      base_rgb = deg_colors(Degradation)/255,
      shade_rgb = shade_colors(Shading)/255,
      # Combine: shading darkens the base color
      r = (1 - Shading) * base_rgb[1] + Shading * shade_rgb[1],
      g = (1 - Shading) * base_rgb[2] + Shading * shade_rgb[2],
      b = (1 - Shading) * base_rgb[3] + Shading * shade_rgb[3],
      color = rgb(r, g, b)
    )
  
  # Tile size
  tile_width  <- 0.9
  tile_height <- 0.9
  
  # Plot
  ggplot(df, aes(x = Col, y = Row)) +
    geom_tile(
      aes(fill = color),
      color = "white",
      width = tile_width,
      height = tile_height,
      linewidth = 0.6
    ) +
    scale_fill_identity() +
    coord_fixed(ratio = 1 / aspect_ratio) +
    scale_y_reverse() +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = NA))
}
