-- SILVER: viajes validos, limpios y sin duplicados.
-- Materializada como tabla y reconstruida en cada corrida: si se re-ejecuta
-- el pipeline, el resultado es el mismo (idempotente).
select
    trip_id,
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance_mi,
    rate_code_id,
    store_and_fwd_flag,
    pickup_location_id,
    dropoff_location_id,
    payment_type_id,
    fare_amount,
    extra_amount,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    total_amount,
    round(trip_duration_sec / 60, 2) as trip_duration_min,
    source_period,
    _source_file,
    _loaded_at
from {{ ref('slv_trips_flagged') }}
where reject_reason is null
-- DUPLICADOS: nos quedamos con una sola fila por viaje (la carga mas reciente)
qualify row_number() over (partition by trip_id order by _loaded_at desc, _source_file) = 1
