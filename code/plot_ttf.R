# -------------------------------------------------------------
# plot_ttf.R — Visualize Time to Failure (TTF)
# -------------------------------------------------------------

library(ggplot2)
library(dplyr)

plot_ttf <- function(ttf_data) {
  ggplot(ttf_data, aes(x = reorder(panel_id, time_to_failure), y = time_to_failure)) +
    geom_col(fill = "#4CAF50") +
    geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
    coord_flip() +
    theme_minimal(base_size = 14) +
    labs(
      title = "Estimated Time to Failure (TTF)",
      x = "Panel ID",
      y = "Hours Until Failure"
    ) +
    theme(
      plot.background = element_rect(fill = "#F7F9FB", color = NA),
      panel.grid.minor = element_blank(),
      axis.text.y = element_text(size = 9)
    )
}
