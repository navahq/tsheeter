# --- build stage ---

FROM elixir:1.10 AS app_builder

ENV MIX_ENV=prod \
    TEST=1 \
    LANG=C.UTF-8

RUN mix local.hex --force && \
    mix local.rebar --force

RUN mkdir /app
WORKDIR /app

COPY config ./config
COPY lib ./lib
COPY priv ./priv
COPY mix.exs .
COPY mix.lock .

RUN mix deps.get
RUN mix deps.compile
RUN mix phx.digest
RUN mix release

# --- application stage ---

FROM debian:buster AS app

ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y openssl && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home app
WORKDIR /home/app
COPY --from=app_builder /app/_build .
RUN chown -R app: ./prod
USER app

CMD ["./prod/rel/tsheeter/bin/tsheeter", "start"]