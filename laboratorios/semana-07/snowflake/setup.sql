-- =====================================================================
-- Laboratorio Integrador I - NYC Yellow Taxi ELT
-- snowflake/setup.sql
-- Crea toda la infraestructura en Snowflake. Es re-ejecutable (IF NOT EXISTS).
-- Ejecutar como ACCOUNTADMIN.
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- 1) Rol del pipeline (minimo privilegio: el pipeline NO usa ACCOUNTADMIN)
CREATE ROLE IF NOT EXISTS TRANSFORMER;
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;          -- buena practica: jerarquia de roles
SET my_user = CURRENT_USER();
GRANT ROLE TRANSFORMER TO USER IDENTIFIER($my_user); -- para que tu usuario tambien pueda usarlo

-- 2) Warehouse pequeno que se apaga solo tras 60 s sin uso (ahorra creditos)
CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
GRANT USAGE, OPERATE ON WAREHOUSE NYC_TAXI_WH TO ROLE TRANSFORMER;

-- 3) Permiso para que TRANSFORMER cree la base de datos (asi queda como duena)
GRANT CREATE DATABASE ON ACCOUNT TO ROLE TRANSFORMER;

-- 4) Usuario dedicado al pipeline (dbt y Kestra se conectan con este)
--    CAMBIA la contrasena antes de ejecutar y guardala en el .env.
--    Politica de Snowflake: minimo 14 caracteres, con mayuscula, minuscula y numero.
--    Si el usuario ya existe, cambiarla con:
--      ALTER USER ELT_USER SET PASSWORD = '<nueva>' MINS_TO_UNLOCK = 0;
CREATE USER IF NOT EXISTS ELT_USER
  PASSWORD = 'CambiaEstaClave2026'
  DEFAULT_ROLE = TRANSFORMER
  DEFAULT_WAREHOUSE = NYC_TAXI_WH
  MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE TRANSFORMER TO USER ELT_USER;

-- ---------------------------------------------------------------------
-- A partir de aqui todo se crea con el rol TRANSFORMER (queda como owner)
-- ---------------------------------------------------------------------
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 5) Base de datos y capas
CREATE DATABASE IF NOT EXISTS NYC_TAXI;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.RAW;     -- aterrizaje: copia fiel de los parquet
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.BRONZE;  -- dbt
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.SILVER;  -- dbt
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.GOLD;    -- dbt

-- 6) Formato de archivo parquet
--    USE_LOGICAL_TYPE = TRUE -> los timestamps llegan como TIMESTAMP, no como enteros
CREATE FILE FORMAT IF NOT EXISTS NYC_TAXI.RAW.PARQUET_FF
  TYPE = PARQUET
  USE_LOGICAL_TYPE = TRUE;

-- 7) Stage interno donde Kestra sube los parquet antes del COPY INTO
CREATE STAGE IF NOT EXISTS NYC_TAXI.RAW.TAXI_STAGE
  FILE_FORMAT = NYC_TAXI.RAW.PARQUET_FF;

-- 8) Tabla RAW: columnas del data dictionary del TLC + metadata de carga
--    Tipos cercanos a la fuente; el casteo fino se hace (y se justifica) en Silver.
CREATE TABLE IF NOT EXISTS NYC_TAXI.RAW.YELLOW_TRIPDATA (
    VendorID               NUMBER,
    tpep_pickup_datetime   TIMESTAMP_NTZ,
    tpep_dropoff_datetime  TIMESTAMP_NTZ,
    passenger_count        FLOAT,
    trip_distance          FLOAT,
    RatecodeID             FLOAT,
    store_and_fwd_flag     VARCHAR,
    PULocationID           NUMBER,
    DOLocationID           NUMBER,
    payment_type           NUMBER,
    fare_amount            FLOAT,
    extra                  FLOAT,
    mta_tax                FLOAT,
    tip_amount             FLOAT,
    tolls_amount           FLOAT,
    improvement_surcharge  FLOAT,
    total_amount           FLOAT,
    congestion_surcharge   FLOAT,
    Airport_fee            FLOAT,
    cbd_congestion_fee     FLOAT,          -- nueva desde enero 2025
    _source_file           VARCHAR,        -- metadata: archivo de origen
    _loaded_at             TIMESTAMP_NTZ   -- metadata: fecha de carga
);

-- 9) Verificacion
SHOW SCHEMAS IN DATABASE NYC_TAXI;
DESC TABLE NYC_TAXI.RAW.YELLOW_TRIPDATA;
LIST @NYC_TAXI.RAW.TAXI_STAGE;   -- debe salir vacio, sin error
