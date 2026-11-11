ARG BASE_IMAGE=ghcr.io/actions/actions-runner:latest
FROM ${BASE_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libatomic1 gzip \
    && rm -rf /var/lib/apt/lists/*
USER runner
