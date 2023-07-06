FROM golang:1.20.4 AS builder

ARG GARM_REV=fdfcc61
ARG GARM_PROVIDER_AZURE_REV=2f9b248

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

FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
	ca-certificates \
	gettext-base

RUN mkdir -p /etc/garm /root/.local/share/garm-cli
RUN ln -s /etc/garm/cli-config.toml /root/.local/share/garm-cli/config.toml

COPY --from=builder /build/garm /usr/bin
COPY --from=builder /build/garm-cli /usr/bin
COPY --from=builder /build/garm-provider-azure /usr/bin

COPY ./config.toml.tmpl /
COPY ./azure-config.toml.tmpl /
COPY ./init.sh /
