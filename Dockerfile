FROM debian:stable-slim

LABEL "com.github.actions.name"="Rsync Deploy"
LABEL "com.github.actions.description"="Deploy to a remote server with rsync via ssh."
LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="orange"

RUN apt-get update && \
    apt-get install -y \
    openssh-client \
    wget \
    curl \
    php \
    git \
    zip \
    jq \
    rsync && \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
