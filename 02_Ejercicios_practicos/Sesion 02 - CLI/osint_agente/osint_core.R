# -----------------------------------------------------------------------------
# osint_core.R · funciones compartidas por el CLI y la app Shiny.
# Solo define funciones y utilidades; no ejecuta nada al hacer source().
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(xml2)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(glue)
})

# Locale C para que %a/%b interpreten nombres en inglés (RSS de Google News)
Sys.setlocale("LC_TIME", "C")

# Operador default para NULL / vacío (escalar)
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (is.character(x) && !nzchar(x))) y else x
}

# 1. Cliente de Wikipedia -----------------------------------------------------
buscar_wikipedia <- function(consulta, lang = "es") {
  url <- glue("https://{lang}.wikipedia.org/w/api.php")
  resp <- request(url) %>%
    req_url_query(
      action = "opensearch",
      search = consulta,
      limit  = 1,
      format = "json"
    ) %>%
    req_user_agent("osint-agente-RRII/0.1 (educativo)") %>%
    req_retry(max_tries = 3) %>%
    req_timeout(20) %>%
    req_perform() %>%
    resp_body_json()

  if (length(resp[[2]]) == 0) return(NULL)
  list(
    titulo = resp[[2]][[1]],
    url    = resp[[4]][[1]],
    lang   = lang
  )
}

wiki_pagina <- function(titulo, lang = "es") {
  url <- glue("https://{lang}.wikipedia.org/w/api.php")
  resp <- request(url) %>%
    req_url_query(
      action      = "query",
      prop        = "extracts",
      exlimit     = 1,
      explaintext = 1,
      redirects   = 1,
      titles      = titulo,
      format      = "json"
    ) %>%
    req_user_agent("osint-agente-RRII/0.1 (educativo)") %>%
    req_timeout(20) %>%
    req_perform() %>%
    resp_body_json()

  pagina <- resp$query$pages[[1]]
  list(
    titulo = pagina$title %||% titulo,
    texto  = pagina$extract %||% ""
  )
}

# Intento ES, fallback EN si no hay página en español
obtener_wikipedia <- function(consulta) {
  meta <- tryCatch(buscar_wikipedia(consulta, "es"), error = function(e) NULL)
  if (is.null(meta)) {
    meta <- tryCatch(buscar_wikipedia(consulta, "en"), error = function(e) NULL)
  }
  if (is.null(meta)) {
    return(list(meta = list(titulo = NULL, url = NULL, lang = NA_character_),
                texto = ""))
  }
  pagina <- tryCatch(
    wiki_pagina(meta$titulo, meta$lang),
    error = function(e) list(titulo = meta$titulo, texto = "")
  )
  list(meta = meta, texto = pagina$texto)
}

# 2. Cliente de Google News RSS ----------------------------------------------
fetch_google_news <- function(consulta, n = 20,
                              hl = "es-419", gl = "MX",
                              ceid = "MX:es") {
  consulta_enc <- utils::URLencode(consulta, reserved = TRUE)
  url <- glue(
    "https://news.google.com/rss/search?",
    "q={consulta_enc}&hl={hl}&gl={gl}&ceid={ceid}"
  )

  resp <- request(url) %>%
    req_user_agent("osint-agente-RRII/0.1 (educativo)") %>%
    req_retry(max_tries = 3) %>%
    req_timeout(25) %>%
    req_perform()

  doc   <- read_xml(resp_body_raw(resp) %>% rawToChar())
  items <- xml_find_all(doc, ".//item")

  if (length(items) == 0) return(tibble())

  extract_field <- function(node_set, xpath) {
    vapply(node_set, function(it) {
      n <- xml_find_first(it, xpath)
      if (inherits(n, "xml_missing")) NA_character_ else xml_text(n)
    }, character(1))
  }

  tibble(
    titulo   = extract_field(items, "./title"),
    enlace   = extract_field(items, "./link"),
    fuente   = extract_field(items, "./source"),
    pub_date = extract_field(items, "./pubDate"),
    resumen  = extract_field(items, "./description")
  ) %>%
    mutate(
      # Google News RSS: "Fri, 17 Apr 2026 04:00:00 GMT"
      fecha = suppressWarnings(
        as.POSIXct(pub_date,
                   format = "%a, %d %b %Y %H:%M:%S", tz = "GMT")
      )
    ) %>%
    arrange(desc(fecha)) %>%
    slice_head(n = n)
}

# 3. Extracción de timeline (hitos con año explícito en Wikipedia) -----------
extraer_hitos_wiki <- function(texto) {
  if (!nzchar(texto)) return(tibble())

  año_actual <- year(Sys.Date())
  oraciones  <- texto %>%
    str_split("(?<=[\\.\\?!])\\s+") %>%
    unlist()

  tibble(oracion = oraciones) %>%
    mutate(
      año = str_extract(oracion, "\\b(1[89]\\d{2}|20\\d{2})\\b")
    ) %>%
    filter(!is.na(año)) %>%
    mutate(año = as.integer(año)) %>%
    filter(año >= 1900, año <= año_actual) %>%
    distinct(oracion, año) %>%
    arrange(año)
}

# 4. Render del perfil en markdown -------------------------------------------
render_perfil <- function(nombre, wiki_meta, wiki_texto, noticias, hitos) {
  ahora <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")

  hitos_md <- if (nrow(hitos) == 0) {
    "_No se detectaron fechas explícitas en el resumen de Wikipedia._"
  } else {
    hitos %>%
      slice_head(n = 25) %>%
      mutate(
        limpia    = str_squish(oracion),
        fragmento = if_else(nchar(limpia) > 220,
                            paste0(str_sub(limpia, 1, 217), "…"),
                            limpia),
        linea     = glue("- **{año}** — {fragmento}")
      ) %>%
      pull(linea) %>%
      paste(collapse = "\n")
  }

  noticias_md <- if (nrow(noticias) == 0) {
    "_Sin resultados en Google News._"
  } else {
    noticias %>%
      mutate(
        fecha_str  = if_else(is.na(fecha),
                             "fecha desconocida",
                             format(fecha, "%Y-%m-%d")),
        fuente_str = coalesce(na_if(str_squish(fuente), ""),
                              "fuente no declarada"),
        linea = glue("- **{fecha_str}** · [{titulo}]({enlace}) — _{fuente_str}_")
      ) %>%
      pull(linea) %>%
      paste(collapse = "\n")
  }

  resumen_md <- if (!nzchar(wiki_texto)) {
    "_Sin página de Wikipedia encontrada._"
  } else {
    recorte <- wiki_texto %>% str_sub(1, 2000) %>% str_squish()
    paste0(recorte, if (nchar(wiki_texto) > 2000) "…" else "")
  }

  wiki_url    <- wiki_meta$url    %||% "—"
  wiki_titulo <- wiki_meta$titulo %||% "—"
  wiki_lang   <- wiki_meta$lang   %||% "—"

  glue(
    "# Perfil OSINT · {nombre}\n\n",
    "_Generado: {ahora}_\n\n",
    "> **Aviso.** Documento OSINT automatizado a partir de fuentes abiertas ",
    "(Wikipedia, Google News). Puede contener errores, sesgos o información ",
    "desactualizada. Verificar antes de citar o usar en decisiones.\n\n",
    "## 1. Identidad y fuentes base\n\n",
    "- **Nombre consultado:** {nombre}\n",
    "- **Página Wikipedia ({wiki_lang}):** [{wiki_titulo}]({wiki_url})\n",
    "- **Noticias recuperadas:** {nrow(noticias)} (Google News RSS · hl=es-419, gl=MX)\n",
    "- **Hitos detectados en Wikipedia:** {nrow(hitos)}\n\n",
    "## 2. Resumen biográfico (Wikipedia)\n\n",
    "{resumen_md}\n\n",
    "## 3. Timeline histórica\n\n",
    "{hitos_md}\n\n",
    "## 4. Cobertura reciente (Google News)\n\n",
    "{noticias_md}\n\n",
    "---\n",
    "_Generado por `osint_agente.R` · uso educativo (RRII)._\n",
    .trim = FALSE
  )
}

# 5. Utilidad: slug seguro para nombres de archivo ---------------------------
slug_safe <- function(x) {
  x %>%
    str_to_lower() %>%
    iconv(to = "ASCII//TRANSLIT") %>%
    str_replace_all("[^a-z0-9]+", "-") %>%
    str_replace_all("^-|-$", "")
}

# 6. Orquestación: flujo completo del agente ---------------------------------
# `log_fn` permite inyectar un logger distinto (p. ej. shiny::showNotification)
ejecutar_agente <- function(nombre, n_noticias = 20, ruta_salida = NULL,
                            log_fn = function(msg) print(msg)) {
  log_fn(sprintf("[1/4] Buscando '%s' en Wikipedia…", nombre))
  wiki <- obtener_wikipedia(nombre)
  if (!is.null(wiki$meta$titulo)) {
    log_fn(sprintf("    → página (%s): %s", wiki$meta$lang, wiki$meta$titulo))
  } else {
    log_fn("    → sin coincidencias en Wikipedia (es/en)")
  }

  log_fn(sprintf("[2/4] Consultando Google News (n=%d)…", n_noticias))
  noticias <- tryCatch(
    fetch_google_news(nombre, n = n_noticias),
    error = function(e) {
      log_fn(sprintf("    ! Error en Google News: %s", conditionMessage(e)))
      tibble()
    }
  )
  log_fn(sprintf("    → %d noticias recuperadas", nrow(noticias)))

  log_fn("[3/4] Extrayendo timeline desde Wikipedia…")
  hitos <- extraer_hitos_wiki(wiki$texto)
  log_fn(sprintf("    → %d hitos con año", nrow(hitos)))

  log_fn("[4/4] Renderizando perfil…")
  md <- render_perfil(nombre, wiki$meta, wiki$texto, noticias, hitos)

  if (!is.null(ruta_salida)) {
    writeLines(md, ruta_salida, useBytes = TRUE)
    log_fn(sprintf("    → guardado en %s", ruta_salida))
  }

  list(
    nombre     = nombre,
    meta       = wiki$meta,
    wiki_texto = wiki$texto,
    noticias   = noticias,
    hitos      = hitos,
    markdown   = md,
    ruta       = ruta_salida
  )
}
