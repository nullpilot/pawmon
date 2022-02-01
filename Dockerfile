ARG BUILDER_IMAGE="hexpm/elixir:1.12.3-erlang-24.1.7-alpine-3.14.2"
ARG RUNNER_IMAGE="alpine:3.14.2"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apk add --no-cache --update git build-base nodejs npm

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

# compile assets
# RUN mix assets.deploy

# Compile the release
COPY lib lib

# build assets
COPY assets assets
RUN mix assets.deploy
RUN cd assets && npm ci && npm run deploy
RUN mix phx.digest

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# prepare release image
FROM ${RUNNER_IMAGE} AS app
RUN apk add --no-cache --update bash openssl libstdc++

WORKDIR /app

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/paw_mon ./
USER nobody

ENV HOME=/app

CMD ["/app/bin/server"]
