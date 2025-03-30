FROM postgres:latest

# Instalacja zależności
RUN apt-get update && apt-get install -y \
    postgresql-server-dev-17 \
    gcc \
    make \
    && rm -rf /var/lib/apt/lists/*

# Instalacja pg_cron
RUN apt-get update && apt-get install -y postgresql-17-cron

# Ustawienie shared_preload_libraries
RUN echo "shared_preload_libraries = 'pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name='mydatabase'" >> /usr/share/postgresql/postgresql.conf.sample
