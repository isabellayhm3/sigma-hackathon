library(shiny)
library(ggplot2)
library(dplyr)
library(readr)

# ---- Source scripts ----
source("code/calculate_performance.R")
source("code/plot_panel_map.R")
source("code/control_chart.R")
source("code/calculate_ttf.R")
source("code/plot_ttf.R")

# ---- UI ----
ui <- fluidPage(
  titlePanel("Solar Panel Performance Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("datafile", "Upload Solar Data CSV",
                accept = c(".csv"),
                buttonLabel = "Browse...",
                placeholder = "No file selected"),
      br(),
      uiOutput("upload_status"),
      width = 3
    ),
    
    mainPanel(
      tabsetPanel(
        
        # ---------- TAB 1: DAILY AVERAGE MAP ----------
        tabPanel("Daily Averages",
                 br(),
                 div(style = "font-style: italic; color: #555; margin-bottom: 10px;",
                     "Performance values are normalized using Six Sigma principles: 1.0 represents the mean performance across all panels, while 0 corresponds to a value three standard deviations below the mean."),
                 plotOutput("daily_map", height = "600px"),
                 br(),
                 uiOutput("low_panel_message"),
        ),
        
        # ---------- TAB 2: HOURLY PERFORMANCE (0–23) ----------
        tabPanel("Hourly Performance",
                 sliderInput(
                   "hour",
                   "Select Hour (0–23):",
                   min = 0, max = 23, value = 12, step = 1,
                   animate = animationOptions(interval = 900, loop = TRUE)
                 ),
                 br(),
                 div(style = "font-style: italic; color: #555; margin-bottom: 10px;",
                     "Hourly performance is displayed on a 0–1 scale, where 1.0 represents the mean power output for that hour, and 0 indicates a value three standard deviations below the mean. 
              Nighttime hours (0–5, 19–23) typically show near-zero output and are displayed in darker blue."),
                 plotOutput("hourly_map", height = "600px")
        ),
        
        # ---------- TAB 3: CONTROL CHART ----------
        tabPanel("Control Chart",
                 br(),
                 div(style = "font-style: italic; color: #555; margin-bottom: 10px;",
                     "This X̄ control chart displays the mean voltage across all panels at 12:00 PM, with ±3σ control limits derived from process variation."),
                 plotOutput("control_chart", height = "600px")
        ),
        
        # ---------- TAB 4: TIME TO FAILURE ----------
        tabPanel("Time to Failure",
                 br(),
                 div(style = "font-style: italic; color: #555; margin-bottom: 10px;",
                     "This analysis estimates the predicted hours remaining until each panel’s output falls below 70% of its baseline value."),
                 plotOutput("ttf_plot", height = "600px"),
                 uiOutput("ttf_summary")
        )
      ),
      width = 9
    )
  )
)

# ---- SERVER ----
server <- function(input, output, session) {
  
  # ---- 1. Reactive file processing ----
  perf_data <- reactive({
    req(input$datafile)
    
    tryCatch({
      perf <- calculate_performance(input$datafile$datapath)
      output$upload_status <- renderUI({
        div(style = "color: green; font-weight: bold; margin-top: 10px;",
            paste("File loaded successfully:", input$datafile$name))
      })
      return(perf)
    },
    error = function(e) {
      output$upload_status <- renderUI({
        div(style = "color: red; font-weight: bold; margin-top: 10px;",
            paste("Error loading file:", e$message))
      })
      return(NULL)
    })
  })
  
  # ---- 2. Daily average performance map ----
  output$daily_map <- renderPlot({
    req(perf_data())
    plot_panel_map(perf_data()$daily,
                   value_col = "avg_power",
                   title = "Average Daily Panel Performance")
  })
  
  # ---- 3. Low performance alert ----
  output$low_panel_message <- renderUI({
    req(perf_data())
    daily <- perf_data()$daily
    low_perf <- daily %>% filter(avg_power < 0.6)
    
    if (nrow(low_perf) == 0) return(NULL)
    
    panel_list <- paste(low_perf$panel_id, collapse = ", ")
    
    div(
      style = "padding: 15px; background-color: #fff3cd; border-left: 5px solid #ffb300;
             margin-top: 10px; border-radius: 5px;",
      strong("Performance Alert: "),
      HTML(paste0(
        "Panels ", panel_list,
        " are performing more than two standard deviations below the mean.<br><br>",
        "<em>Note:</em> Clusters of adjacent underperforming panels often indicate <strong>shading</strong> (environmental obstruction), ",
        "while isolated underperforming panels are more likely signs of <strong>degradation</strong> or electrical issues."
      ))
    )
  })
  
  # ---- 4. Shading vs. degradation message ----
  output$shade_degrade_message <- renderUI({
    req(perf_data())
    daily <- perf_data()$daily
    
    msg <- detect_shading_vs_degradation(daily, threshold = 0.6)
    
    div(
      style = "padding: 15px; background-color: #e9f7ef; border-left: 5px solid #28a745; 
               margin-top: 10px; border-radius: 5px;",
      HTML(paste("<strong>System Diagnostic:</strong>", msg))
    )
  })
  
  # ---- 4. Hourly performance map (full 24h) ----
  output$hourly_map <- renderPlot({
    req(perf_data())
    hourly <- perf_data()$hourly
    df_filtered <- hourly %>% filter(hour == input$hour)
    plot_panel_map(df_filtered,
                   value_col = "norm_power",
                   title = paste("Hourly Performance —", sprintf("%02d:00", input$hour)))
  })
  
  # ---- 5. Control chart (12:00 PM) ----
  output$control_chart <- renderPlot({
    req(input$datafile)
    average_chart(input$datafile$datapath)
  })
  
  # ---- 6. Mean Time to Failure plot ----
  output$ttf_plot <- renderPlot({
    req(input$datafile)
    ttf <- calculate_ttf(input$datafile$datapath)
    plot_ttf(ttf$ttf_results, top_n = 10)
  })
  
  # ---- 7. MTTF summary text ----
  output$ttf_summary <- renderUI({
    req(input$datafile)
    ttf <- calculate_ttf(input$datafile$datapath)
    div(
      style = "margin-top: 15px; color: #333; background-color: #f9f9f9; padding: 12px; border-radius: 6px;",
      HTML(paste0(
        "<strong>Mean Time to Failure (MTTF):</strong> ",
        round(ttf$mean_ttf, 2), " hours <br>",
        "<em>Panels with predicted failure &lt; 50 hours are highlighted in red for priority inspection.</em>"
      ))
    )
  })
}

# ---- Run App ----
shinyApp(ui, server)
