-- BRONZE: lo mas cercano posible a la fuente.
-- No se renombra, castea ni filtra nada; solo se agrega metadata de linaje.
select
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    RatecodeID,
    store_and_fwd_flag,
    PULocationID,
    DOLocationID,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    Airport_fee,
    cbd_congestion_fee,
    -- metadata
    _source_file,                                             -- archivo de origen
    regexp_substr(_source_file, '[0-9]{4}-[0-9]{2}') as source_period,  -- periodo YYYY-MM
    _loaded_at                                                -- fecha de carga
from {{ source('raw', 'yellow_tripdata') }}
