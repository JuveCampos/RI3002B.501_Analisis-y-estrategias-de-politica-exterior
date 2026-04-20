# -----------------------------------------------------------------------------
# osint_agente.R — wrapper CLI sobre osint_core.R.
#
# Uso:
#   Rscript osint_agente.R "Nombre del actor" [n_noticias]
#   OSINT_SELFTEST=1 Rscript osint_agente.R
# -----------------------------------------------------------------------------

# Resuelve la ruta del script actual (compatible con Rscript y source())
args_full <- commandArgs(trailingOnly = FALSE)
file_arg  <- grep("^--file=", args_full, value = TRUE)
este_dir  <- if (length(file_arg) > 0) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  "."
}

source(file.path(este_dir, "osint_core.R"))

dir.create(file.path(este_dir, "perfiles"), showWarnings = FALSE)

# 1. Auto-test (se activa con OSINT_SELFTEST=1) ------------------------------
if (Sys.getenv("OSINT_SELFTEST") == "1") {
  caso_prueba <- "Marcelo Ebrard"
  print(glue("=== AUTO-TEST con '{caso_prueba}' ==="))
  res <- ejecutar_agente(
    caso_prueba, 15,
    ruta_salida = file.path(
      este_dir, "perfiles",
      paste0(slug_safe(caso_prueba), "_test.md"))
  )

  stopifnot("Wikipedia no respondió"          = !is.null(res$meta$url))
  stopifnot("Google News no devolvió items"   = nrow(res$noticias) > 0)
  stopifnot("Markdown sospechosamente corto"  = nchar(res$markdown) > 1000)
  stopifnot("Timeline vacía"                  = nrow(res$hitos) > 0)

  print("✓ Auto-test OK")
  print(glue("  archivo: {res$ruta}"))
  print(glue("  noticias={nrow(res$noticias)} · hitos={nrow(res$hitos)} · ",
             "md={nchar(res$markdown)} chars"))
  quit(status = 0)
}

# 2. Ejecución normal desde CLI ----------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Uso: Rscript osint_agente.R \"Nombre del actor\" [n_noticias]")
}
nombre_actor <- args[[1]]
n_noticias   <- as.integer(if (length(args) >= 2) args[[2]] else 20)

ruta_out <- file.path(este_dir, "perfiles",
                      paste0(slug_safe(nombre_actor), ".md"))

resultado <- ejecutar_agente(nombre_actor, n_noticias, ruta_out)
print(glue(
  "✓ Perfil generado: {resultado$ruta} · ",
  "noticias={nrow(resultado$noticias)} · hitos={nrow(resultado$hitos)}"
))
