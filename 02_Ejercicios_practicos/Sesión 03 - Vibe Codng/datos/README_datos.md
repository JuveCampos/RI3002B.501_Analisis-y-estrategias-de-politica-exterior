# Datos para el Taller de Ciencia de Datos e IA para Relaciones Internacionales

Este paquete contiene dos archivos CSV con **datos reales y verificables** para los ejercicios 1 y 2 del pack de vibe coding. El ejercicio 3 usa la API del Banco Mundial (WDI) y no requiere CSV.

---

## 📄 `comercio_tmec.csv` — Comercio bilateral de EEUU con sus socios del T-MEC

**Fuente:** U.S. Census Bureau, Foreign Trade Statistics

**URLs originales:**
- México: https://www.census.gov/foreign-trade/balance/c2010.html
- Canadá: https://www.census.gov/foreign-trade/balance/c1220.html

**Perspectiva:** Estados Unidos. El Census Bureau reporta exportaciones e importaciones de EEUU con cada socio comercial.

**Cobertura:** 2000-2024 (totales anuales).

**Unidades:** Millones de dólares estadounidenses nominales (no ajustados por inflación, no ajustados estacionalmente).

**Filas:** 100 (25 años × 2 países × 2 tipos de flujo)

### Diccionario de variables

| Columna | Tipo | Descripción |
|---|---|---|
| `year` | int | Año calendario |
| `pais` | str | Código del socio comercial: `MEX` (México) o `CAN` (Canadá) |
| `tipo_flujo` | str | `exportacion` = EEUU exporta a `pais`; `importacion` = EEUU importa de `pais` |
| `valor_usd_millones` | float | Valor en millones de USD nominales |

### Cómo calcular el saldo comercial

El saldo comercial de EEUU con un socio es `exportaciones − importaciones`. Cuando es negativo, EEUU tiene déficit (y el socio tiene superávit). Ejemplo para 2024:

```
Saldo EEUU-México 2024 = 334,031.9 − 505,523.2 = −171,491.3 millones USD
```

Esto significa que **México tuvo un superávit comercial de USD $171,491 millones con EEUU en 2024**, récord histórico. Este dato fue central en las tensiones arancelarias de 2025.

### Notas metodológicas importantes (para discusión en clase)

1. **Valores nominales, no reales.** No están ajustados por inflación. Un dólar de 2000 compra menos que uno de 2024. Para análisis de largo plazo conviene deflactar.
2. **Solo bienes (goods), no servicios.** Los servicios se reportan por separado.
3. **Perspectiva de EEUU.** Por convenciones de comercio internacional, los datos de México con EEUU vistos desde INEGI/Banxico difieren ligeramente debido a ajustes de valoración (FOB vs CIF) y atribución geográfica (puerto de entrada vs. origen real).

---

## 📄 `asilo_centroamerica.csv` — Solicitudes de asilo centroamericano en Norteamérica

**Fuente:** UNHCR Refugee Data Finder (ACNUR)

**URL original:** https://www.unhcr.org/refugee-statistics/download

**API usada para generar este CSV:**
```
https://api.unhcr.org/population/v1/asylum-applications/?yearFrom=2010&yearTo=2024&coo=HND,SLV,GTM,NIC&coa=MEX,USA,CAN&cf_type=ISO
```

**Cobertura:** 2010-2024.

**Indicador:** `applied` (nuevas solicitudes de asilo presentadas en el año, suma de todos los tipos de procedimiento).

**Filas:** 180 (15 años × 4 orígenes × 3 destinos). Las combinaciones sin solicitudes reportadas tienen valor `0`.

### Diccionario de variables

| Columna | Tipo | Descripción |
|---|---|---|
| `year` | int | Año calendario |
| `country_origin` | str | País de origen (ISO3): `HND` Honduras, `SLV` El Salvador, `GTM` Guatemala, `NIC` Nicaragua |
| `country_asylum` | str | País donde se presenta la solicitud (ISO3): `MEX`, `USA`, `CAN` |
| `applications` | int | Número de solicitudes nuevas de asilo presentadas en ese año |

### Notas metodológicas importantes (para discusión en clase)

1. **Solicitudes ≠ refugiados reconocidos ≠ migrantes.** Este CSV cuenta *nuevas solicitudes de asilo presentadas*. Una persona puede solicitar asilo y serle negado; puede migrar sin solicitar asilo; puede ser refugiada y no aparecer en este dataset. La distinción es política y técnica, importante para un internacionalista.
2. **Valores pequeños redondeados.** UNHCR redondea valores menores a 5 al múltiplo de 5 más cercano por confidencialidad.
3. **Las cifras de USA incluyen solicitudes afirmativas y defensivas** a diferentes instancias (USCIS, cortes migratorias). Son altas y difíciles de comparar 1-a-1 con las de México (COMAR).
4. **El año 2024 es preliminar**; UNHCR publica datos consolidados a mediados del año siguiente.
5. **Contexto histórico clave:**
   - Honduras → USA: tendencia creciente desde 2014 con la "crisis de menores no acompañados".
   - Honduras → México: explosión post-2017 (caravanas, política de "Remain in Mexico").
   - Nicaragua → USA en 2023: pico histórico (90,902 solicitudes) tras la crisis política de 2018.

### Top 5 flujos históricos del dataset

| Año | Origen | Destino | Solicitudes |
|---|---|---|---|
| 2023 | Nicaragua | EEUU | 90,902 |
| 2019 | Guatemala | EEUU | 55,314 |
| 2017 | El Salvador | EEUU | 49,726 |
| 2023 | Honduras | EEUU | 49,691 |
| 2022 | Honduras | EEUU | 44,072 |

---

## 📋 Ajuste al Ejercicio 1 del pack de prompts

Como los datos del Census son desde la perspectiva de EEUU, el prompt debe decir "saldo comercial de EEUU con sus socios del T-MEC", no "de México". Esto de hecho enriquece el ejercicio porque permite discutir el ángulo de Trump y los déficits comerciales. El prompt revisado es:

```
Actúa como un analista de datos experto en R y visualización con ggplot2.

Tengo un archivo CSV llamado `comercio_tmec.csv` en mi directorio de trabajo con las
columnas: year (int), pais (MEX o CAN), tipo_flujo (exportacion o importacion),
valor_usd_millones (float). Los datos son del U.S. Census Bureau y representan el
comercio de bienes de Estados Unidos con sus socios del T-MEC, 2000-2024.

Quiero que hagas lo siguiente paso a paso:

1. Carga el archivo con readr::read_csv() y muéstrame su estructura con glimpse()
   y summary(). Confirma que no hay valores faltantes.

2. Usa dplyr::pivot_wider() para pasar de formato largo a ancho y luego calcula
   el saldo comercial anual de EEUU con cada país (exportaciones menos
   importaciones). El resultado debe tener columnas: year, pais,
   saldo_usd_millones.

3. Genera una gráfica con ggplot2 que muestre dos series de tiempo (EEUU-México
   y EEUU-Canadá) del saldo comercial de 2000 a 2024.

4. La gráfica debe tener:
   - Título: "Saldo comercial de Estados Unidos con sus socios del T-MEC"
   - Subtítulo: "Exportaciones menos importaciones de bienes, 2000-2024"
   - Eje Y en miles de millones de USD con formato legible (divide
     valor_usd_millones entre 1000 y usa scales::label_number con
     prefix = "$" y suffix = " mmd")
   - Una línea horizontal en cero con geom_hline(yintercept=0, linetype="dashed")
     para marcar la frontera entre déficit y superávit
   - Colores distintivos por país: usa scale_color_manual con valores
     c("MEX" = "#006847", "CAN" = "#D52B1E")  # bandera de México y Canadá
   - theme_minimal(base_size = 12) con legend.position = "top"
   - Caption al pie: "Fuente: U.S. Census Bureau, Foreign Trade Statistics.
     Millones de USD nominales."

5. Guarda la gráfica como `saldo_tmec.png` en 1200x800 px con ggsave() y dpi=150.

IMPORTANTE:
- Antes de escribir el código, describe en 3 líneas qué vas a hacer.
- Después del código, explícame qué se ve en la gráfica y qué año destaca.
- Verifica los resultados: el saldo EEUU-México 2024 debe ser aproximadamente
  -171,491 millones USD. Si obtienes algo muy diferente, revisa tu código.
```

---

## Cómo repartir estos archivos a los estudiantes

Sugerencia de estructura de carpeta para el día del taller:

```
taller_vibe_coding/
├── datos/
│   ├── comercio_tmec.csv
│   ├── asilo_centroamerica.csv
│   └── README_datos.md         ← este archivo
├── prompts/
│   ├── 01_comercio_tmec.md
│   ├── 02_asilo_centroamerica.md
│   └── 03_rule_of_law.md
├── outputs/
└── scripts/
```

Los estudiantes colocan el repositorio en su carpeta personal, abren RStudio en el proyecto, y apuntan sus agentes de IA al working directory correcto.
