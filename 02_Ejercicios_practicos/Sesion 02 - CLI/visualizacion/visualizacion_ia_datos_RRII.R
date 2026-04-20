# -----------------------------------------------------------------------------
# Visualización: exposición a IA generativa vs. uso de datos
# en actividades profesionales de Relaciones Internacionales (RRII)
#
# Entrada : tabla_ia_cd_RRII.xlsx (columnas Alto/Medio/Bajo)
# Salidas : tabla_ia_cd_RRII_numerica.csv  (tabla con valores numéricos)
#           grafico_ia_datos_RRII.png      (scatter plot por cuadrantes)
# -----------------------------------------------------------------------------

# Carga de librerías (agrupadas al inicio)
library(readxl)
library(dplyr)
library(ggplot2)
library(ggrepel)
library(readr)

# 1. Cargar la tabla original -------------------------------------------------
ruta_xlsx <- "tabla_ia_cd_RRII.xlsx"

datos_raw <- read_excel(ruta_xlsx) %>%
  rename(
    actividad   = `Actividad (RRII)`,
    ia_nivel    = `Impacto potencial de IA generativa`,
    datos_nivel = `Uso/valor de datos y ciencia de datos`
  )

# 2. Asignar valor numérico a cada dimensión ---------------------------------
# Escala ordinal: Bajo = 1, Medio = 2, Alto = 3
niveles <- c("Bajo" = 1, "Medio" = 2, "Alto" = 3)

datos <- datos_raw %>%
  mutate(
    id          = row_number(),
    ia_valor    = niveles[ia_nivel],
    datos_valor = niveles[datos_nivel]
  )

# 3. Clasificar cuadrantes ----------------------------------------------------
# Umbral en 2.5: "Alto" (nivel Alto) vs. "Bajo" (Bajo o Medio)
datos <- datos %>%
  mutate(
    cuadrante = case_when(
      ia_valor >= 2.5 & datos_valor >= 2.5 ~ "Alta IA · Alto Datos",
      ia_valor >= 2.5 & datos_valor <  2.5 ~ "Alta IA · Bajo Datos",
      ia_valor <  2.5 & datos_valor >= 2.5 ~ "Baja IA · Alto Datos",
      TRUE                                 ~ "Baja IA · Bajo Datos"
    )
  )

# Resumen por cuadrante (conteo de actividades)
conteos <- datos %>%
  count(cuadrante, name = "n_actividades") %>%
  arrange(desc(n_actividades))

print(conteos)

# 4. Gráfico de dispersión con cuadrantes ------------------------------------
set.seed(42)  # jitter reproducible

paleta <- c(
  "Alta IA · Alto Datos" = "#1b7837",
  "Alta IA · Bajo Datos" = "#d95f02",
  "Baja IA · Alto Datos" = "#1f78b4",
  "Baja IA · Bajo Datos" = "#7f7f7f"
)

grafico <- datos %>%
  ggplot(aes(x = ia_valor, y = datos_valor, color = cuadrante)) +
  # líneas divisorias de cuadrantes
  geom_hline(yintercept = 2.5, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = 2.5, linetype = "dashed", color = "grey40") +
  # puntos con jitter (muchas actividades comparten coordenadas)
  geom_jitter(width = 0.18, height = 0.18, alpha = 0.85, size = 2.6) +
  # etiquetas = id de actividad (se consultan en tabla_ia_cd_RRII_numerica.csv)
  geom_text_repel(
    aes(label = id),
    size          = 2.8,
    max.overlaps  = Inf,
    segment.color = "grey70",
    segment.size  = 0.3,
    show.legend   = FALSE
  ) +
  # etiquetas de cuadrante (esquinas)
  annotate("text", x = 3.45, y = 3.45, label = "Alta IA\nAlto Datos",
           hjust = 1, vjust = 1, fontface = "bold",
           size  = 4.2, alpha = 0.55, color = "#1b7837") +
  annotate("text", x = 0.55, y = 3.45, label = "Baja IA\nAlto Datos",
           hjust = 0, vjust = 1, fontface = "bold",
           size  = 4.2, alpha = 0.55, color = "#1f78b4") +
  annotate("text", x = 3.45, y = 0.55, label = "Alta IA\nBajo Datos",
           hjust = 1, vjust = 0, fontface = "bold",
           size  = 4.2, alpha = 0.55, color = "#d95f02") +
  annotate("text", x = 0.55, y = 0.55, label = "Baja IA\nBajo Datos",
           hjust = 0, vjust = 0, fontface = "bold",
           size  = 4.2, alpha = 0.55, color = "#7f7f7f") +
  scale_x_continuous(
    breaks = 1:3, labels = c("Bajo", "Medio", "Alto"),
    limits = c(0.4, 3.6)
  ) +
  scale_y_continuous(
    breaks = 1:3, labels = c("Bajo", "Medio", "Alto"),
    limits = c(0.4, 3.6)
  ) +
  scale_color_manual(values = paleta) +
  labs(
    title    = "Actividades de RRII: exposición a IA vs. uso de datos",
    subtitle = "Escala ordinal (Bajo = 1, Medio = 2, Alto = 3) · Cuadrantes con umbral = 2.5",
    x        = "Exposición / impacto potencial de IA generativa",
    y        = "Uso / valor de datos y ciencia de datos",
    color    = "Cuadrante",
    caption  = "Fuente: tabla_ia_cd_RRII.xlsx · Etiquetas = id de actividad (ver CSV de salida)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold")
  )

print(grafico)

# 5. Exportar salidas ---------------------------------------------------------
tabla_salida <- datos %>%
  select(id, actividad,
         ia_nivel, ia_valor,
         datos_nivel, datos_valor,
         cuadrante)

write_csv(tabla_salida, "tabla_ia_cd_RRII_numerica.csv")

ggsave(
  filename = "grafico_ia_datos_RRII.png",
  plot     = grafico,
  width    = 12, height = 9, dpi = 300, bg = "white"
)

# Mensaje de cierre con número de actividades procesadas
print(sprintf("Procesadas %d actividades · cuadrantes: %d",
              nrow(datos), nrow(conteos)))
