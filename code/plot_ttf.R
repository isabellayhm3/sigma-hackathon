
# Generate MTTF Plot

library(ggplot2)
library(dplyr)
library(scales)

plot_ttf <- function(ttf_results, top_n = 10) {
  
  # --- Clean & Rank ---
  ttf_clean <- ttf_results %>%
    filter(is.finite(time_to_failure)) %>%
    arrange(time_to_failure) %>%
    slice_head(n = top_n) %>%
    mutate(
      risk_category = case_when(
        time_to_failure < 50  ~ "High Risk (<50 h)",
        time_to_failure < 100 ~ "Moderate (50–100 h)",
        TRUE                  ~ "Low Risk (>100 h)"
      ),
      risk_category = factor(risk_category,
                             levels = c("High Risk (<50 h)",
                                        "Moderate (50–100 h)",
                                        "Low Risk (>100 h)"))
    )
  
  # --- Color palette (red → yellow → green) ---
  risk_colors <- c(
    "High Risk (<50 h)"    = "#D32F2F",
    "Moderate (50–100 h)"  = "#FBC02D",
    "Low Risk (>100 h)"    = "#388E3C"
  )
  
  # --- Plot ---
  ggplot(ttf_clean, aes(x = reorder(panel_id, time_to_failure), 
                        y = time_to_failure, 
                        fill = risk_category)) +
    geom_col(width = 0.6) +
    coord_flip() +
    geom_text(aes(label = paste0(round(time_to_failure, 1), " h")), 
              hjust = -0.1, size = 3.5, color = "black") +
    scale_fill_manual(values = risk_colors, name = "Risk Level") +
    labs(
      title = paste("Top", top_n, "Panels at Risk of Failure"),
      subtitle = "Predicted time until output drops below 70% of baseline",
      x = "Panel ID",
      y = "Predicted Time to Failure (hours)"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold"),
      axis.text.y = element_text(size = 10),
      legend.position = "top",
      panel.grid.major.y = element_blank(),
      plot.margin = margin(20, 20, 20, 20)
    ) +
    ylim(0, max(ttf_clean$time_to_failure, na.rm = TRUE) * 1.3)
}
