FROM mambaorg/micromamba:1.5.8

USER root

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y bc less mawk sed && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /nc-variants
RUN chown $MAMBA_USER:$MAMBA_USER /nc-variants

USER $MAMBA_USER

ENV BASH_ENV /etc/bash.bashrc

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml

RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

COPY --chown=$MAMBA_USER:$MAMBA_USER ./nc-variants.sh ./nc-variant-files.sh ./
