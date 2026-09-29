# Imagen de Kestra + dbt-snowflake.
# Asi Kestra puede ejecutar dbt directamente (tarea shell con Process runner),
# usando el proyecto montado en /app/dbt y las variables ENV_SNOWFLAKE_* del .env.
FROM kestra/kestra:latest

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv \
 && python3 -m venv /opt/dbt \
 && /opt/dbt/bin/pip install --no-cache-dir "dbt-core>=1.10,<2" "dbt-snowflake>=1.10,<2" \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/dbt/bin:${PATH}"
