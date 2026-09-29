# Laboratorio Integrador I — Tubería ELT NYC Yellow Taxi

Tubería ELT reproducible que **ingiere** los archivos mensuales de NYC Yellow Taxi (enero 2025 – agosto 2026), los **carga** a Snowflake y los **transforma** con dbt en una arquitectura **Bronze → Silver → Gold** con un esquema estrella listo para análisis.

| Pieza | Tecnología |
|---|---|
| Infraestructura | Docker Compose (Kestra 2.0 + Postgres), imagen propia con dbt |
| Ingesta (E + L) | Flow de Kestra `nyc_taxi_elt` |
| Data warehouse | Snowflake (`NYC_TAXI`: RAW, BRONZE, SILVER, GOLD) |
| Transformación (T) | dbt-core + dbt-snowflake + dbt_utils |
| Validación | 46 tests de dbt (`not_null`, `unique`, `relationships`, `accepted_values`, `expression_is_true`) |

- Diagrama de arquitectura: [`docs/arquitectura.md`](docs/arquitectura.md)
- Diagrama del esquema estrella: [`docs/esquema_estrella.md`](docs/esquema_estrella.md)

---

## 1. Estructura del repositorio

```
semana-07/
├── docker-compose.yml        # Kestra + Postgres
├── Dockerfile                # Kestra + dbt-snowflake
├── .env.example              # plantilla de credenciales (copiar a .env)
├── snowflake/setup.sql       # warehouse, DB, schemas, stage, file format, tabla RAW, rol y usuario
├── kestra/flows/
│   ├── test_snowflake.yml    # prueba de conexión
│   └── nyc_taxi_elt.yml      # ingesta + dbt build
├── dbt/nyc_taxi/             # proyecto dbt
│   ├── seeds/                # catálogos del TLC (zonas, vendors, tarifas, pagos)
│   └── models/bronze | silver | gold
└── docs/                     # diagramas
```

## 2. Cómo levantar y ejecutar desde cero

**Prerrequisitos:** Docker Desktop y una cuenta de Snowflake (trial sirve).

1. **Snowflake.** En una hoja SQL, como `ACCOUNTADMIN`, ejecutar [`snowflake/setup.sql`](snowflake/setup.sql) completo (**Run All**). Antes, cambiar la contraseña de `ELT_USER` (mínimo 14 caracteres, con mayúscula, minúscula y número). El script es re-ejecutable (`IF NOT EXISTS`).
2. **Credenciales.** Copiar `.env.example` como `.env` y completar la cuenta (`ORG-CUENTA`, tomada de la URL de Snowflake) y la contraseña. El `.env` está en `.gitignore`.
3. **Catálogo de zonas.** Si no existe, descargarlo:
   ```powershell
   Invoke-WebRequest -Uri "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv" -OutFile "dbt\nyc_taxi\seeds\taxi_zone_lookup.csv"
   ```
4. **Infraestructura.**
   ```bash
   docker compose up -d --build
   ```
   UI de Kestra en http://localhost:8080 (`admin@kestra.io` / `Admin1234`).
5. **Flows.** En Kestra → *Flows → Create*, pegar y guardar `kestra/flows/test_snowflake.yml` y `kestra/flows/nyc_taxi_elt.yml`. Ejecutar primero `test_snowflake` para validar la conexión.
6. **Pipeline completo.** Ejecutar `nyc_taxi_elt` (por defecto carga los 20 meses y al final corre `dbt build`).

Para ejecutar solo dbt (útil al depurar):
```bash
docker compose exec kestra bash -c "cd /app/dbt/nyc_taxi && dbt deps --profiles-dir . && dbt build --profiles-dir ."
```

## 3. Ingesta (Kestra)

Por cada mes (`Loop`, 2 en paralelo):

| # | Tarea | Qué hace |
|---|---|---|
| 1 | `download` | Descarga `yellow_tripdata_YYYY-MM.parquet` del TLC |
| 2 | `upload_stage` | `PUT` al stage interno `@RAW.TAXI_STAGE/yellow/` |
| 3 | `delete_previo` | Borra de RAW las filas de **ese mismo archivo** |
| 4 | `copy_into` | `COPY INTO RAW.YELLOW_TRIPDATA` con `MATCH_BY_COLUMN_NAME` y `INCLUDE_METADATA` (`_source_file`, `_loaded_at`) |
| 5 | `limpiar_stage` | Elimina el parquet del stage |

Luego, `resumen` cuenta filas por archivo y `dbt_build` construye y prueba todas las capas.

**Idempotencia.** Re-ejecutar un mes **reemplaza** sus filas (DELETE + COPY) en vez de sumarlas. En dbt todos los modelos se reconstruyen desde RAW, así que si RAW no tiene duplicados, tampoco los tienen las capas siguientes.

> **Evidencia:** `2025-01` tenía 3,475,226 filas (`_loaded_at` 15:58). Tras re-ejecutarlo quedó en **3,475,226** filas (`_loaded_at` 17:09): se recargó sin duplicar. *(capturas en `docs/`)*

**Nota sobre agosto 2026:** al 28/09/2026 el TLC aún no publica Yellow Taxi de 2026-08 (responde HTTP 403). El `Loop` usa `transmitFailed: false`, así que ese mes falla de forma aislada, se cargan los otros 19 y el flow continúa. Cuando el TLC lo publique, basta re-ejecutar el flow: se agrega sin duplicar nada.

## 4. Capas y decisiones de modelado

### Bronze — `brz_yellow_tripdata` (vista)
Mismas columnas y tipos que la fuente, sin limpieza. Agrega metadata de linaje: `_source_file` (archivo de origen), `source_period` (YYYY-MM) y `_loaded_at` (fecha de carga). Es una vista porque no transforma nada y así no se duplica almacenamiento. Los catálogos del TLC se cargan como **seeds** en este mismo schema: son datos estáticos que se versionan con el código.

### Silver — `slv_trips_flagged` → `slv_yellow_trips` + `slv_quality_report`

| Dimensión de calidad | Problema observado | Decisión | Justificación |
|---|---|---|---|
| Nombres / formatos | `VendorID`, `PULocationID`, `Airport_fee`; flag `Y`/`N` | snake_case; flag → `BOOLEAN` | Convención consistente y tipo semántico correcto |
| Tipos | IDs como float en algunos meses; montos float | IDs → `INTEGER`; montos → `NUMBER(10,2)` | Evitar errores de redondeo y joins con tipos distintos |
| Nulos | `passenger_count`, `RatecodeID` y recargos nulos en bloque | `RatecodeID` nulo → 99 (desconocido); recargos nulos → 0; `passenger_count` se deja NULL | 99 es el código oficial de desconocido; un recargo nulo equivale a no cobrado; imputar pasajeros sesgaría promedios |
| Códigos fuera de diccionario | vendor, zona o pago inválidos | → miembro "desconocido" de la dimensión (-1, 264, 5) | Conserva el viaje y mantiene la integridad referencial |
| Duplicados | No hay llave natural | `trip_id` = hash de vendor, fechas, zonas, distancia, montos y pago; `QUALIFY ROW_NUMBER() = 1` | Dos filas con los mismos atributos son el mismo viaje |
| Registros inválidos | Fechas fuera del mes del archivo, duración ≤ 0 o > 24 h, distancia < 0 o > 200 mi, montos negativos | Se excluyen y se registra el motivo en `reject_reason` | Son errores de captura o anulaciones/reembolsos, no viajes |

`slv_quality_report` cuantifica, por periodo, cuántos registros son válidos y cuántos se descartaron por cada motivo:

```sql
SELECT * FROM NYC_TAXI.SILVER.SLV_QUALITY_REPORT ORDER BY source_period, registros DESC;
```

### Gold — esquema estrella
- **Hecho:** `fct_trips`. **Grano: un viaje válido.** PK `trip_id`.
- **Dimensiones:** `dim_date` (PK `date_key` YYYYMMDD), `dim_time` (PK `hour_key` 0–23), `dim_location` (PK `location_id`; role-playing para pickup y dropoff), `dim_vendor`, `dim_rate_code`, `dim_payment_type`.
- **Métricas:** pasajeros, distancia, duración, tarifa, extras, impuestos, propina, peajes, recargos (congestión, aeropuerto, CBD) y total.
- **Atributos degenerados:** fechas exactas de pickup y dropoff, `store_and_fwd_flag`, `source_period`.

Ver [`docs/esquema_estrella.md`](docs/esquema_estrella.md).

## 5. Validación

`dbt build` ejecuta **46 tests**:

- `unique` + `not_null` en la PK de cada dimensión y en `fct_trips.trip_id` (y en `slv_yellow_trips.trip_id`);
- `relationships` de cada FK de `fct_trips` hacia su dimensión (7 relaciones);
- `accepted_values` en vendor, tarifa y tipo de pago;
- `expression_is_true`: `total_amount >= 0` y `trip_duration_min > 0`;
- `not_null` en la metadata de Bronze (`_source_file`, `source_period`, `_loaded_at`).

**Resultado:** `PASS=61 WARN=0 ERROR=0 SKIP=0 TOTAL=61` (4 seeds, 2 vistas, 9 tablas, 46 tests).

## 6. Uso de IA

Se usó Claude (Anthropic) como guía para diseñar la arquitectura, escribir el código y depurar errores (sintaxis de Kestra 2.0, ruta del stage en `COPY INTO`, política de contraseñas de Snowflake). Las decisiones de limpieza y modelado están explicadas en este README y en los comentarios del código.
