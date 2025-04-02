FROM postgres:latest

RUN apt-get update && apt-get install -y \
    postgresql-server-dev-17 \
    gcc \
    make \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y postgresql-17-cron

RUN echo "shared_preload_libraries = 'pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name='mydatabase'" >> /usr/share/postgresql/postgresql.conf.sample
