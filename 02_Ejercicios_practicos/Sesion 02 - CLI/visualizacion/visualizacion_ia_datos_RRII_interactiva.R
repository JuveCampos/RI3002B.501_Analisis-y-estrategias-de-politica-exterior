# -----------------------------------------------------------------------------
# Versión INTERACTIVA (HTML) del scatter por cuadrantes
# Exposición a IA generativa vs. uso de datos en actividades de RRII.
#
# Entrada : tabla_ia_cd_RRII.xlsx
# Salida  : grafico_ia_datos_RRII.html  (widget plotly autocontenido)
# -----------------------------------------------------------------------------

# Carga de librerías
library(readxl)
library(dplyr)
library(stringr)
library(plotly)
library(htmlwidgets)

# 1. Cargar la tabla original -------------------------------------------------
ruta_xlsx <- "tabla_ia_cd_RRII.xlsx"

datos_raw <- read_excel(ruta_xlsx) %>%
  rename(
    actividad   = `Actividad (RRII)`,
    ia_nivel    = `Impacto potencial de IA generativa`,
    datos_nivel = `Uso/valor de datos y ciencia de datos`
  )

# 2. Asignar valor numérico y cuadrante --------------------------------------
niveles <- c("Bajo" = 1, "Medio" = 2, "Alto" = 3)

datos <- datos_raw %>%
  mutate(
    id          = row_number(),
    ia_valor    = niveles[ia_nivel],
    datos_valor = niveles[datos_nivel],
    cuadrante   = case_when(
      ia_valor >= 2.5 & datos_valor >= 2.5 ~ "Alta IA · Alto Datos",
      ia_valor >= 2.5 & datos_valor <  2.5 ~ "Alta IA · Bajo Datos",
      ia_valor <  2.5 & datos_valor >= 2.5 ~ "Baja IA · Alto Datos",
      TRUE                                 ~ "Baja IA · Bajo Datos"
    )
  )

# 3. Jitter reproducible para evitar sobretrazado ----------------------------
set.seed(42)

datos <- datos %>%
  mutate(
    ia_jit    = ia_valor    + runif(n(), -0.22, 0.22),
    datos_jit = datos_valor + runif(n(), -0.22, 0.22),
    # texto del tooltip (HTML, con saltos cada ~55 caracteres)
    tooltip = paste0(
      "<b>#", id, " — ",
      str_wrap(actividad, width = 55) %>% str_replace_all("\\n", "<br>"),
      "</b>",
      "<br><br>Exposición IA: <b>", ia_nivel,  "</b> (", ia_valor, ")",
      "<br>Uso de datos: <b>", datos_nivel, "</b> (", datos_valor, ")",
      "<br>Cuadrante: <i>", cuadrante, "</i>"
    )
  )

# 4. Paleta por cuadrante -----------------------------------------------------
paleta <- c(
  "Alta IA · Alto Datos" = "#1b7837",
  "Alta IA · Bajo Datos" = "#d95f02",
  "Baja IA · Alto Datos" = "#1f78b4",
  "Baja IA · Bajo Datos" = "#7f7f7f"
)

# 5. Gráfico interactivo con plotly ------------------------------------------
fig <- plot_ly(
  data       = datos,
  x          = ~ia_jit,
  y          = ~datos_jit,
  type       = "scatter",
  mode       = "markers",
  color      = ~cuadrante,
  colors     = paleta,
  text       = ~tooltip,
  hoverinfo  = "text",
  marker     = list(size = 11, opacity = 0.85,
                    line = list(color = "white", width = 1))
)

# Líneas divisorias y anotaciones de cuadrante
lineas_cuadrante <- list(
  list(type = "line", x0 = 2.5, x1 = 2.5, y0 = 0.4, y1 = 3.6,
       line = list(color = "grey40", dash = "dash", width = 1)),
  list(type = "line", x0 = 0.4, x1 = 3.6, y0 = 2.5, y1 = 2.5,
       line = list(color = "grey40", dash = "dash", width = 1))
)

anot_cuadrante <- list(
  list(x = 3.55, y = 3.55, xref = "x", yref = "y",
       text = "<b>Alta IA<br>Alto Datos</b>",
       showarrow = FALSE, font = list(color = "#1b7837", size = 13),
       xanchor = "right", yanchor = "top", opacity = 0.6),
  list(x = 0.45, y = 3.55, xref = "x", yref = "y",
       text = "<b>Baja IA<br>Alto Datos</b>",
       showarrow = FALSE, font = list(color = "#1f78b4", size = 13),
       xanchor = "left",  yanchor = "top", opacity = 0.6),
  list(x = 3.55, y = 0.45, xref = "x", yref = "y",
       text = "<b>Alta IA<br>Bajo Datos</b>",
       showarrow = FALSE, font = list(color = "#d95f02", size = 13),
       xanchor = "right", yanchor = "bottom", opacity = 0.6),
  list(x = 0.45, y = 0.45, xref = "x", yref = "y",
       text = "<b>Baja IA<br>Bajo Datos</b>",
       showarrow = FALSE, font = list(color = "#7f7f7f", size = 13),
       xanchor = "left",  yanchor = "bottom", opacity = 0.6)
)

fig <- fig %>%
  layout(
    title = list(
      text = paste0(
        "<b>Actividades de RRII: exposición a IA vs. uso de datos</b>",
        "<br><sup>Pasa el cursor sobre cada punto para ver la actividad · ",
        "Escala: Bajo = 1, Medio = 2, Alto = 3</sup>"
      ),
      x = 0.02, xanchor = "left"
    ),
    xaxis = list(
      title     = "Exposición / impacto potencial de IA generativa",
      tickvals  = c(1, 2, 3),
      ticktext  = c("Bajo", "Medio", "Alto"),
      range     = c(0.4, 3.6),
      zeroline  = FALSE,
      gridcolor = "grey92"
    ),
    yaxis = list(
      title     = "Uso / valor de datos y ciencia de datos",
      tickvals  = c(1, 2, 3),
      ticktext  = c("Bajo", "Medio", "Alto"),
      range     = c(0.4, 3.6),
      zeroline  = FALSE,
      gridcolor = "grey92"
    ),
    shapes      = lineas_cuadrante,
    annotations = anot_cuadrante,
    legend      = list(orientation = "h", x = 0, y = -0.12,
                       title = list(text = "<b>Cuadrante:</b> ")),
    margin      = list(l = 70, r = 40, t = 90, b = 90),
    plot_bgcolor  = "white",
    paper_bgcolor = "white",
    hoverlabel    = list(bgcolor = "white",
                         font = list(family = "Helvetica", size = 12))
  ) %>%
  config(displaylogo = FALSE,
         modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"))

# 6. Guardar HTML autocontenido ----------------------------------------------
saveWidget(
  widget        = fig,
  file          = "grafico_ia_datos_RRII.html",
  selfcontained = TRUE,
  title         = "RRII · IA vs. Datos (interactivo)"
)

# Mensaje final
print(sprintf("HTML generado con %d actividades · archivo: grafico_ia_datos_RRII.html",
              nrow(datos)))
