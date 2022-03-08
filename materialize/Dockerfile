FROM materialize/materialized:v0.19.0

RUN apt update -qq && apt install -y -qq postgresql-client && \
    echo 'localhost:6875:materialize:materialize' > ~/.pgpass && \
    chmod go-rwx ~/.pgpass
