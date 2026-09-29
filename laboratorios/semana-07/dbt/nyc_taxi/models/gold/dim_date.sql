-- Dimension calendario. Grano: un dia. PK: date_key (YYYYMMDD).
with days as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('date_start') ~ "' as date)",
        end_date="cast('" ~ var('date_end') ~ "' as date)"
    ) }}
)
select
    cast(to_char(date_day, 'YYYYMMDD') as integer) as date_key,
    cast(date_day as date)                         as full_date,
    year(date_day)                                 as year,
    quarter(date_day)                              as quarter,
    month(date_day)                                as month,
    monthname(date_day)                            as month_name,
    day(date_day)                                  as day_of_month,
    dayofweekiso(date_day)                         as day_of_week,     -- 1 = lunes
    dayname(date_day)                              as day_name,
    dayofweekiso(date_day) in (6, 7)               as is_weekend
from days
