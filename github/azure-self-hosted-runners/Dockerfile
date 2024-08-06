FROM golang:1.21.7-bookworm AS builder

ARG GARM_REV=f68cf98
ARG GARM_PROVIDER_AZURE_REV=278e136

RUN mkdir /src /build
RUN git clone https://github.com/cloudbase/garm.git /src/garm
RUN git clone https://github.com/cloudbase/garm-provider-azure /src/garm-provider-azure

WORKDIR /src/garm
RUN git checkout ${GARM_REV}
RUN go build -o /build/garm ./cmd/garm
RUN go build -o /build/garm-cli ./cmd/garm-cli

WORKDIR /src/garm-provider-azure
RUN git checkout ${GARM_PROVIDER_AZURE_REV}
RUN go build -o /build/garm-provider-azure

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	python3-jinja2

RUN mkdir -p /etc/garm /root/.local/share/garm-cli
RUN ln -s /etc/garm/cli-config.toml /root/.local/share/garm-cli/config.toml

COPY --from=builder /build/garm /usr/bin
COPY --from=builder /build/garm-cli /usr/bin
COPY --from=builder /build/garm-provider-azure /usr/bin

COPY ./templates /templates
COPY ./template_config.py /
COPY ./init.sh /
