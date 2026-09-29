-- Dimension zona de taxi (role-playing: sirve para pickup y dropoff). PK: location_id.
select
    LocationID                 as location_id,
    coalesce(Borough, 'Unknown')      as borough,
    coalesce(Zone, 'Unknown')         as zone,
    coalesce(service_zone, 'Unknown') as service_zone
from {{ ref('taxi_zone_lookup') }}
