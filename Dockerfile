FROM mambaorg/micromamba:0.11.3

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y less mawk sed && \
    rm -rf /var/lib/apt/lists/*

ENV BASH_ENV /etc/bash.bashrc

COPY environment.yml /root/environment.yml

RUN micromamba install -y -n base -f /root/environment.yml && \
    micromamba clean --all --yes

RUN groupadd conda && \
        useradd --home-dir /nc-variants --create-home --shell /bin/bash --skel /dev/null -g conda conda

RUN mkdir -p /nc-variants && chown conda:conda /nc-variants

WORKDIR /nc-variants
USER conda

COPY --chown=conda:conda ./nc-variants.sh ./nc-variant-files.sh ./
