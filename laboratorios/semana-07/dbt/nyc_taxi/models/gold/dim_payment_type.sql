-- Dimension forma de pago. PK: payment_type_id.
select payment_type_id, payment_type_name
from {{ ref('payment_types') }}
