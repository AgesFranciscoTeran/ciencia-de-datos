{{ config(materialized='view') }}
-- SILVER (paso intermedio): estandariza nombres/tipos y marca cada registro
-- con el PRIMER motivo por el que seria invalido (reject_reason).
-- Se separa en una vista para reusar la misma logica en:
--   * slv_yellow_trips   -> registros validos
--   * slv_quality_report -> cuantos se descartaron y por que (evidencia)

with src as (
    select * from {{ ref('brz_yellow_tripdata') }}
),

typed as (
    select
        -- NOMBRES: todo a snake_case (VendorID -> vendor_id, PULocationID -> pickup_location_id)
        -- TIPOS: IDs a entero, montos a NUMBER(10,2), flag Y/N a booleano

        -- Codigos fuera del diccionario del TLC -> fila "desconocido" de la dimension
        case when cast(VendorID as integer) in (1, 2, 6, 7)
             then cast(VendorID as integer) else -1 end                 as vendor_id,

        tpep_pickup_datetime                                            as pickup_datetime,
        tpep_dropoff_datetime                                           as dropoff_datetime,

        -- NULOS: passenger_count nulo o 0 se deja NULL (imputarlo sesgaria promedios)
        case when passenger_count > 0
             then cast(passenger_count as integer) end                  as passenger_count,

        cast(trip_distance as number(10, 2))                            as trip_distance_mi,

        -- NULOS: RatecodeID nulo -> 99 (codigo oficial de "desconocido")
        case when cast(RatecodeID as integer) in (1, 2, 3, 4, 5, 6)
             then cast(RatecodeID as integer) else 99 end               as rate_code_id,

        -- FORMATOS: 'Y'/'N' con posibles espacios o minusculas -> booleano
        case upper(trim(store_and_fwd_flag))
             when 'Y' then true when 'N' then false end                 as store_and_fwd_flag,

        -- Zonas fuera de 1..265 -> 264 (zona "Unknown" del catalogo)
        case when PULocationID between 1 and 265
             then cast(PULocationID as integer) else 264 end            as pickup_location_id,
        case when DOLocationID between 1 and 265
             then cast(DOLocationID as integer) else 264 end            as dropoff_location_id,

        -- payment_type fuera de 0..6 -> 5 (Unknown)
        case when cast(payment_type as integer) between 0 and 6
             then cast(payment_type as integer) else 5 end              as payment_type_id,

        cast(fare_amount           as number(10, 2))                    as fare_amount,
        cast(coalesce(extra, 0)                 as number(10, 2))       as extra_amount,
        cast(coalesce(mta_tax, 0)               as number(10, 2))       as mta_tax,
        cast(coalesce(tip_amount, 0)            as number(10, 2))       as tip_amount,
        cast(coalesce(tolls_amount, 0)          as number(10, 2))       as tolls_amount,
        cast(coalesce(improvement_surcharge, 0) as number(10, 2))       as improvement_surcharge,
        -- NULOS: recargos nulos = no se cobro el recargo -> 0
        cast(coalesce(congestion_surcharge, 0)  as number(10, 2))       as congestion_surcharge,
        cast(coalesce(Airport_fee, 0)           as number(10, 2))       as airport_fee,
        cast(coalesce(cbd_congestion_fee, 0)    as number(10, 2))       as cbd_congestion_fee,
        cast(total_amount          as number(10, 2))                    as total_amount,

        datediff('second', tpep_pickup_datetime, tpep_dropoff_datetime) as trip_duration_sec,

        source_period,
        _source_file,
        _loaded_at
    from src
)

select
    -- DUPLICADOS: no hay llave natural -> llave sustituta con los atributos que
    -- definen un viaje. Dos filas con la misma llave son el mismo viaje repetido.
    {{ dbt_utils.generate_surrogate_key([
        'vendor_id', 'pickup_datetime', 'dropoff_datetime',
        'pickup_location_id', 'dropoff_location_id',
        'trip_distance_mi', 'fare_amount', 'total_amount', 'payment_type_id'
    ]) }} as trip_id,
    *,
    -- INVALIDOS: primera regla que el registro incumple (null = valido)
    case
        when pickup_datetime is null or dropoff_datetime is null
            then 'fecha_nula'
        when to_char(pickup_datetime, 'YYYY-MM') <> source_period
            then 'fuera_del_periodo_del_archivo'   -- ej. viajes de 2008 dentro del archivo 2025-03
        when dropoff_datetime <= pickup_datetime
            then 'duracion_no_positiva'
        when trip_duration_sec > 24 * 3600
            then 'duracion_mayor_24h'
        when trip_distance_mi is null or trip_distance_mi < 0
            then 'distancia_negativa'
        when trip_distance_mi > 200
            then 'distancia_mayor_200mi'           -- fuera del rango operativo de un taxi de NYC
        when fare_amount < 0 or total_amount < 0
            then 'monto_negativo'                  -- anulaciones/reembolsos, no son viajes
        when total_amount is null
            then 'monto_nulo'
    end as reject_reason
from typed
