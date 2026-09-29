-- SILVER (evidencia de calidad): cuantos registros entraron, cuantos se
-- descartaron y por que motivo, por periodo. Sirve para justificar la limpieza.
with flagged as (
    select
        source_period,
        coalesce(reject_reason, 'valido') as estado,
        count(*) as registros,
        count(distinct trip_id) as viajes_unicos
    from {{ ref('slv_trips_flagged') }}
    group by 1, 2
)
select
    source_period,
    estado,
    registros,
    registros - viajes_unicos as duplicados_en_estado,
    round(100 * registros / sum(registros) over (partition by source_period), 3) as pct_del_periodo
from flagged
order by source_period, registros desc
