-- Dimension hora del dia. Grano: una hora (0-23). PK: hour_key.
with hours as (
    select row_number() over (order by seq4()) - 1 as hour_key
    from table(generator(rowcount => 24))
)
select
    hour_key,
    lpad(hour_key, 2, '0') || ':00'                     as hour_label,
    case
        when hour_key between 0 and 5   then 'Madrugada'
        when hour_key between 6 and 9   then 'Pico manana'
        when hour_key between 10 and 15 then 'Mediodia'
        when hour_key between 16 and 19 then 'Pico tarde'
        else 'Noche'
    end                                                 as day_part
from hours
