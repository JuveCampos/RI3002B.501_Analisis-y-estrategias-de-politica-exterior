# -----------------------------------------------------------------------------
# app.R · Interfaz Shiny para el agente OSINT.
# Reutiliza íntegramente la lógica de osint_core.R (mismas funciones que el CLI).
#
# Uso:
#   shiny::runApp("app.R")
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(DT)
  library(markdown)
  library(dplyr)
  library(stringr)
  library(glue)
})

# Carga las funciones compartidas (obtener_wikipedia, fetch_google_news,
# extraer_hitos_wiki, render_perfil, slug_safe, ejecutar_agente, …)
source("osint_core.R", local = TRUE)

dir.create("perfiles", showWarnings = FALSE)

# UI --------------------------------------------------------------------------
ui <- page_sidebar(
  title = "Agente OSINT · RRII",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  sidebar = sidebar(
    width = 340,
    title = "Parámetros de búsqueda",

    textInput(
      "nombre", "Nombre del actor",
      value       = "",
      placeholder = "p. ej. Claudia Sheinbaum"
    ),
    sliderInput(
      "n_noticias", "Número de noticias (Google News)",
      min = 5, max = 50, value = 20, step = 5
    ),
    actionButton(
      "run", "Generar perfil",
      icon  = icon("play"),
      class = "btn-primary w-100"
    ),
    hr(),
    downloadButton(
      "descargar", "Descargar Markdown",
      class = "btn-outline-secondary w-100"
    ),
    hr(),
    helpText(
      "Documento OSINT generado a partir de Wikipedia y Google News. ",
      "Uso educativo; verificar antes de citar."
    )
  ),

  navset_card_tab(
    id = "tabs",

    nav_panel(
      "Perfil",
      icon = icon("file-lines"),
      uiOutput("perfil_md")
    ),

    nav_panel(
      "Noticias",
      icon = icon("newspaper"),
      DTOutput("tabla_noticias")
    ),

    nav_panel(
      "Timeline",
      icon = icon("clock-rotate-left"),
      DTOutput("tabla_hitos")
    ),

    nav_panel(
      "Wikipedia",
      icon = icon("wikipedia-w"),
      uiOutput("wiki_header"),
      verbatimTextOutput("wiki_texto")
    ),

    nav_panel(
      "Log",
      icon = icon("terminal"),
      verbatimTextOutput("log_salida")
    )
  )
)

# Server ----------------------------------------------------------------------
server <- function(input, output, session) {

  resultado   <- reactiveVal(NULL)
  log_buffer  <- reactiveVal(character())

  anexar_log <- function(msg) {
    log_buffer(c(log_buffer(), as.character(msg)))
  }

  observeEvent(input$run, {
    nombre <- str_squish(input$nombre)
    req(nzchar(nombre))

    log_buffer(character())
    resultado(NULL)

    withProgress(message = "Ejecutando agente OSINT…", value = 0, {
      # log_fn envía cada paso tanto al buffer (pestaña Log) como a la barra
      # de progreso de Shiny; así se reutiliza ejecutar_agente() sin cambios.
      log_shiny <- function(msg) {
        anexar_log(msg)
        incProgress(1 / 4, detail = msg)
      }

      res <- tryCatch(
        ejecutar_agente(
          nombre       = nombre,
          n_noticias   = input$n_noticias,
          ruta_salida  = file.path(
            "perfiles", paste0(slug_safe(nombre), ".md")
          ),
          log_fn = log_shiny
        ),
        error = function(e) {
          anexar_log(sprintf("✗ Error: %s", conditionMessage(e)))
          showNotification(
            paste("Error:", conditionMessage(e)),
            type = "error", duration = 8
          )
          NULL
        }
      )

      if (!is.null(res)) {
        resultado(res)
        showNotification(
          glue("Perfil generado · {nrow(res$noticias)} noticias · ",
               "{nrow(res$hitos)} hitos"),
          type = "message", duration = 5
        )
      }
    })
  })

  # Perfil renderizado como HTML desde el markdown generado por render_perfil()
  output$perfil_md <- renderUI({
    res <- resultado()
    if (is.null(res)) {
      return(div(
        class = "text-muted p-3",
        "Escribe un nombre y pulsa ",
        tags$b("Generar perfil"), " para comenzar."
      ))
    }
    HTML(markdown::markdownToHTML(
      text     = res$markdown,
      fragment.only = TRUE,
      options  = c("use_xhtml", "smartypants")
    ))
  })

  output$tabla_noticias <- renderDT({
    res <- resultado()
    req(res)
    if (nrow(res$noticias) == 0) {
      return(datatable(
        tibble(mensaje = "Sin resultados en Google News."),
        options = list(dom = "t"), rownames = FALSE
      ))
    }
    res$noticias %>%
      mutate(
        fecha = if_else(
          is.na(fecha), "—", format(fecha, "%Y-%m-%d %H:%M")
        ),
        titulo = sprintf(
          '<a href="%s" target="_blank" rel="noopener">%s</a>',
          enlace, htmltools::htmlEscape(titulo)
        )
      ) %>%
      select(fecha, titulo, fuente) %>%
      datatable(
        escape   = FALSE,
        rownames = FALSE,
        options  = list(pageLength = 10, order = list(list(0, "desc")))
      )
  })

  output$tabla_hitos <- renderDT({
    res <- resultado()
    req(res)
    if (nrow(res$hitos) == 0) {
      return(datatable(
        tibble(mensaje = "No se detectaron fechas explícitas en Wikipedia."),
        options = list(dom = "t"), rownames = FALSE
      ))
    }
    res$hitos %>%
      mutate(oracion = str_squish(oracion)) %>%
      select(año, oracion) %>%
      datatable(
        rownames = FALSE,
        options  = list(pageLength = 15, order = list(list(0, "asc")))
      )
  })

  output$wiki_header <- renderUI({
    res <- resultado()
    req(res)
    titulo <- res$meta$titulo %||% "—"
    url    <- res$meta$url    %||% NULL
    lang   <- res$meta$lang   %||% "—"

    tagList(
      h4(titulo),
      if (!is.null(url)) {
        p(tags$a(href = url, target = "_blank", rel = "noopener", url))
      },
      p(tags$small(glue("Idioma de la página: {lang}")))
    )
  })

  output$wiki_texto <- renderText({
    res <- resultado()
    req(res)
    if (!nzchar(res$wiki_texto)) {
      return("Sin página de Wikipedia encontrada.")
    }
    res$wiki_texto
  })

  output$log_salida <- renderText({
    logs <- log_buffer()
    if (length(logs) == 0) "(sin actividad)" else paste(logs, collapse = "\n")
  })

  output$descargar <- downloadHandler(
    filename = function() {
      res <- resultado()
      nombre <- if (!is.null(res)) res$nombre else "perfil"
      paste0(slug_safe(nombre), ".md")
    },
    content = function(file) {
      res <- resultado()
      req(res)
      writeLines(res$markdown, file, useBytes = TRUE)
    }
  )
}

shinyApp(ui, server)
