-- Dimension proveedor tecnologico (TPEP). PK: vendor_id. Incluye -1 = Desconocido.
select vendor_id, vendor_name
from {{ ref('vendors') }}
