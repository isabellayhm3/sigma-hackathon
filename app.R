# -------------------------------------------------------------
# app.R — Solar Panel Health Dashboard
# -------------------------------------------------------------
# Features:
# - Upload CSV input
# - Compute hourly statistics
# - Classify shading vs. degradation
# - Display condition map
# - Estimate and plot Time to Failure (TTF)
# - Placeholder Control Chart tab
# -------------------------------------------------------------

options(repos = c(CRAN = "https://cloud.r-project.org"))

library(shiny)
library(ggplot2)
library(dplyr)
library(readr)
library(tools)

# --- Load helper functions ---
source("code/calculate_stats.R")     # hourly_stats_array()
source("code/classify_panels.R")     # classify_panels()
source("code/plot_panel_map.R")      # plot_panel_map()
source("code/calculate_ttf.R")       # calculate_ttf()
source("code/plot_ttf.R")            # plot_ttf()

# -------------------------------------------------------------
# USER INTERFACE
# -------------------------------------------------------------
ui <- fluidPage(
  titlePanel("☀️ Solar Panel Health Dashboard"),

  sidebarLayout(
    sidebarPanel(
      fileInput(
        "file_upload",
        "Upload Solar Data (CSV):",
        accept = c(".csv")
      ),
      actionButton("run", "Run Analysis", class = "btn-primary"),
      br(), br(),
      h4("Legend"),
      tags$ul(
        tags$li("🟩 Green → Healthy"),
        tags$li("🟨 Yellow → Mild Degradation"),
        tags$li("🟥 Red → Severe Degradation"),
        tags$li("⬛ Dark Tint → Shading Influence"),
        tags$li("⬜ Gray → No Sunlight (Nighttime)")
      ),
      hr(),
      helpText("Upload a CSV with columns: panel_id, hour (or time), voltage, current.")
    ),

    mainPanel(
      tabsetPanel(
        type = "tabs",

        # --- Tab 1: Condition Map ---
        tabPanel("Condition Map",
                 plotOutput("panel_map", height = "600px"),
                 br(),
                 tableOutput("summary_table")
        ),

        # --- Tab 2: Time Till Failure ---
        tabPanel("Time Till Failure",
                 h3("Predicted Time to Failure (TTF)"),
                 p("Estimated number of hours until each panel is expected to fall below 70% of its initial power output."),
                 br(),
                 plotOutput("ttf_plot", height = "500px"),
                 br(),
                 tableOutput("ttf_summary")
        ),

        # --- Tab 3: Control Chart (placeholder) ---
        tabPanel("Control Chart",
                 h3("Statistical Process Control"),
                 p("This section shows hourly variation and 3σ control limits for monitoring process stability."),
                 br(),
                 plotOutput("control_chart", height = "400px"),
                 br(),
                 p("Use this to detect drift, unusual variance, or measurement noise.")
        )
      )
    )
  )
)

# -------------------------------------------------------------
# SERVER LOGIC
# -------------------------------------------------------------
server <- function(input, output, session) {

  # --- Data processing pipeline ---
  results <- eventReactive(input$run, {
    req(input$file_upload)

    # === 1️⃣ Read and clean uploaded file ===
    file_path <- input$file_upload$datapath
    raw_data <- readr::read_csv(file_path, show_col_types = FALSE)

    # Clean and standardize column names
    names(raw_data) <- names(raw_data) %>%
      trimws() %>%
      tolower() %>%
      gsub("\\s+", "_", .) %>%
      gsub("[^a-z0-9_]", "", .)

    # === 2️⃣ Handle "hour" vs "time" naming ===
    if ("hour" %in% names(raw_data) && !("time" %in% names(raw_data))) {
      raw_data <- raw_data %>% rename(time = hour)
    }

    # === 3️⃣ Validate required columns ===
    validate(
      need("panel_id" %in% names(raw_data), "❌ Missing 'panel_id' column in CSV."),
      need("time" %in% names(raw_data), "❌ Missing 'time' or 'hour' column in CSV."),
      need("voltage" %in% names(raw_data), "❌ Missing 'voltage' column in CSV."),
      need("current" %in% names(raw_data), "❌ Missing 'current' column in CSV.")
    )

    # === 4️⃣ Save cleaned data to a temporary CSV ===
    cleaned_path <- tempfile(fileext = ".csv")
    readr::write_csv(raw_data, cleaned_path)

    # === 5️⃣ Run hourly stats ===
    hourly_stats <- hourly_stats_array(cleaned_path)

    baseline_file <- paste0("hourly_stats_", tools::file_path_sans_ext(basename(cleaned_path)), ".csv")
    write.csv(hourly_stats, baseline_file, row.names = TRUE)

    # === 6️⃣ Run panel classification ===
    classified_summary <- classify_panels(
      data_file = cleaned_path,
      baseline_file = baseline_file
    ) %>%
      rename(PanelID = panel_id)

    list(hourly = hourly_stats, classified = classified_summary, raw = cleaned_path)
  })

  # --- Tab 1: Condition Map ---
  output$panel_map <- renderPlot({
    req(results())
    plot_panel_map(results()$classified, nrows = 10, total_panels = 100)
  })

  output$summary_table <- renderTable({
    req(results())
    as.data.frame(
      results()$classified %>%
        summarise(
          Avg_Shading = round(mean(Shading, na.rm = TRUE), 3),
          Avg_Degradation = round(mean(Degradation, na.rm = TRUE), 3),
          Affected_Panels = sum(Shading > 0 | Degradation > 0)
        )
    )
  })

  # --- Tab 2: Time Till Failure (TTF) ---
  output$ttf_plot <- renderPlot({
    req(results())
    ttf_data <- calculate_ttf(results()$raw)
    plot_ttf(ttf_data)
  })

  output$ttf_summary <- renderTable({
    req(results())
    ttf_data <- calculate_ttf(results()$raw)
    as.data.frame(ttf_data %>%
      summarise(
        Avg_TTF = round(mean(time_to_failure, na.rm = TRUE), 2),
        Min_TTF = round(min(time_to_failure, na.rm = TRUE), 2),
        Max_TTF = round(max(time_to_failure, na.rm = TRUE), 2)
      )
    )
  })

  # --- Tab 3: Control Chart (placeholder for now) ---
  output$control_chart <- renderPlot({
    req(results())
    ggplot() +
      annotate("text", x = 1, y = 1,
               label = "📈 Control Chart feature under development!",
               size = 6, color = "#607D8B") +
      theme_void() +
      theme(plot.background = element_rect(fill = "#F7F9FB", color = NA))
  })
}

# -------------------------------------------------------------
# Run the App
# -------------------------------------------------------------
shinyApp(ui, server)
