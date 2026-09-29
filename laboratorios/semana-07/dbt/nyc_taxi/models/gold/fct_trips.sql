-- TABLA DE HECHOS
-- Grano: UN viaje valido de Yellow Taxi (una fila por trip_id).
-- FKs -> dim_vendor, dim_rate_code, dim_payment_type, dim_location (x2),
--        dim_date (fecha de pickup), dim_time (hora de pickup).
select
    -- llave
    trip_id,

    -- llaves foraneas
    vendor_id,
    rate_code_id,
    payment_type_id,
    pickup_location_id,
    dropoff_location_id,
    cast(to_char(pickup_datetime, 'YYYYMMDD') as integer) as pickup_date_key,
    hour(pickup_datetime)                                 as pickup_hour_key,

    -- atributos degenerados (propios del viaje, no justifican dimension)
    pickup_datetime,
    dropoff_datetime,
    store_and_fwd_flag,
    source_period,

    -- metricas
    passenger_count,
    trip_distance_mi,
    trip_duration_min,
    fare_amount,
    extra_amount,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    total_amount
from {{ ref('slv_yellow_trips') }}
