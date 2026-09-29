-- Dimension tarifa. PK: rate_code_id. Incluye 99 = Desconocido.
select rate_code_id, rate_code_name
from {{ ref('rate_codes') }}
