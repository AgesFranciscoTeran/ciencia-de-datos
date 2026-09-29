# Diagrama de arquitectura

```mermaid
flowchart LR
    TLC["NYC TLC<br/>yellow_tripdata_YYYY-MM.parquet<br/>(CloudFront)"]

    subgraph DOCKER["Docker Compose (local)"]
        PG[("Postgres<br/>metadata Kestra")]
        subgraph KESTRA["Kestra 2.0 + dbt-snowflake"]
            L["Loop por mes<br/>download → PUT stage<br/>DELETE archivo → COPY INTO<br/>REMOVE stage"]
            D["dbt build<br/>seeds + modelos + tests"]
        end
        KESTRA --- PG
    end

    subgraph SF["Snowflake · DB NYC_TAXI · WH NYC_TAXI_WH (XS)"]
        ST[/"@RAW.TAXI_STAGE/yellow/"/]
        RAW[("RAW.YELLOW_TRIPDATA<br/>+ _source_file, _loaded_at")]
        BR["BRONZE<br/>brz_yellow_tripdata (vista)<br/>+ seeds"]
        SI["SILVER<br/>slv_trips_flagged → slv_yellow_trips<br/>slv_quality_report"]
        GO["GOLD<br/>fct_trips + 6 dimensiones"]
    end

    TLC -->|HTTP| L
    L -->|PUT| ST
    ST -->|COPY INTO| RAW
    RAW --> BR --> SI --> GO
    D -.->|ejecuta| BR
    D -.-> SI
    D -.-> GO
```

| Componente | Rol | Tecnología |
|---|---|---|
| Orquestación / ingesta (E + L) | Descarga cada mes y lo carga a RAW de forma idempotente | Kestra 2.0 en Docker |
| Almacenamiento | Stage interno + tabla RAW | Snowflake |
| Transformación (T) | Bronze → Silver → Gold + tests | dbt-core + dbt-snowflake (dentro de la imagen de Kestra) |
| Metadata del orquestador | Estado de flows y ejecuciones | Postgres 16 |
