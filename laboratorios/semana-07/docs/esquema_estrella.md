# Diagrama del esquema estrella (capa GOLD)

**Grano de `fct_trips`:** un viaje válido de Yellow Taxi (una fila por `trip_id`).

```mermaid
erDiagram
    FCT_TRIPS }o--|| DIM_VENDOR : "vendor_id"
    FCT_TRIPS }o--|| DIM_RATE_CODE : "rate_code_id"
    FCT_TRIPS }o--|| DIM_PAYMENT_TYPE : "payment_type_id"
    FCT_TRIPS }o--|| DIM_LOCATION : "pickup_location_id"
    FCT_TRIPS }o--|| DIM_LOCATION : "dropoff_location_id"
    FCT_TRIPS }o--|| DIM_DATE : "pickup_date_key"
    FCT_TRIPS }o--|| DIM_TIME : "pickup_hour_key"

    FCT_TRIPS {
        varchar trip_id PK "hash de atributos del viaje"
        int vendor_id FK
        int rate_code_id FK
        int payment_type_id FK
        int pickup_location_id FK
        int dropoff_location_id FK
        int pickup_date_key FK "YYYYMMDD"
        int pickup_hour_key FK "0-23"
        timestamp pickup_datetime "degenerado"
        timestamp dropoff_datetime "degenerado"
        boolean store_and_fwd_flag "degenerado"
        varchar source_period "linaje"
        int passenger_count "metrica"
        number trip_distance_mi "metrica"
        number trip_duration_min "metrica"
        number fare_amount "metrica"
        number extra_amount "metrica"
        number mta_tax "metrica"
        number tip_amount "metrica"
        number tolls_amount "metrica"
        number improvement_surcharge "metrica"
        number congestion_surcharge "metrica"
        number airport_fee "metrica"
        number cbd_congestion_fee "metrica"
        number total_amount "metrica"
    }
    DIM_VENDOR {
        int vendor_id PK
        varchar vendor_name
    }
    DIM_RATE_CODE {
        int rate_code_id PK
        varchar rate_code_name
    }
    DIM_PAYMENT_TYPE {
        int payment_type_id PK
        varchar payment_type_name
    }
    DIM_LOCATION {
        int location_id PK
        varchar borough
        varchar zone
        varchar service_zone
    }
    DIM_DATE {
        int date_key PK
        date full_date
        int year
        int quarter
        int month
        varchar month_name
        int day_of_month
        int day_of_week
        varchar day_name
        boolean is_weekend
    }
    DIM_TIME {
        int hour_key PK
        varchar hour_label
        varchar day_part
    }
```

- `DIM_LOCATION` es una *role-playing dimension*: la misma tabla responde como zona de origen y de destino.
- Cada dimensión de catálogo incluye un miembro "desconocido" (`vendor -1`, `rate_code 99`, `payment 5`, `location 264`) para que toda FK tenga pareja y el test `relationships` sea válido sin descartar viajes.
