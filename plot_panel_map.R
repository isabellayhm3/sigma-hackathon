library(ggplot2)
library(dplyr)

plot_panel_map <- function(panel_data, nrows, total_panels, aspect_ratio = 2) {
  # Colors for green, shading, and degradation
  green_rgb <- c(0, 230, 0)       # healthy
  red_rgb   <- c(230, 0, 0)       # degradation
  grey_rgb  <- c(63, 94, 122)     # shading
  
  # Normalize RGB to 0-1 for the degradation and shading factors
  green_rgb <- green_rgb / 255
  red_rgb   <- red_rgb / 255
  grey_rgb  <- grey_rgb / 255
  
  # Calculate number of columns
  ncols <- ceiling(total_panels / nrows)
  
  # Generate grid positions
  panel_positions <- expand.grid(
    Row = seq_len(nrows),
    Col = seq_len(ncols)
  ) %>%
    mutate(PanelID = sprintf("P%03d", seq_len(n())))
  
  # Merge with data
  df <- left_join(panel_positions, panel_data, by = "PanelID") %>%
    mutate(
      Degradation = ifelse(is.na(Degradation), 0, Degradation),
      Shading = ifelse(is.na(Shading), 0, Shading)
    )
  
  # Compute blended color
  df <- df %>%
    rowwise() %>%
    mutate(
      r = green_rgb[1] * (1 - Degradation - Shading) +
        red_rgb[1] * Degradation +
        grey_rgb[1] * Shading,
      g = green_rgb[2] * (1 - Degradation - Shading) +
        red_rgb[2] * Degradation +
        grey_rgb[2] * Shading,
      b = green_rgb[3] * (1 - Degradation - Shading) +
        red_rgb[3] * Degradation +
        grey_rgb[3] * Shading,
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
    theme(
      plot.background = element_rect(fill = "white", color = NA)
    )
}
