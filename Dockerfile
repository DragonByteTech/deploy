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
    gpg \ 
    rsync && \ 
    rm -rf /var/lib/apt/lists/*

ENV JQ_VERSION='1.5'

RUN wget --no-check-certificate https://raw.githubusercontent.com/jqlang/jq/master/sig/jq-release-old.key -O /tmp/jq-release.key && \
    wget --no-check-certificate https://raw.githubusercontent.com/jqlang/jq/master/sig/v${JQ_VERSION}/jq-linux64.asc -O /tmp/jq-linux64.asc && \
    wget --no-check-certificate https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64 && \
    gpg --import /tmp/jq-release.key && \
    gpg --verify /tmp/jq-linux64.asc /tmp/jq-linux64 && \
    cp /tmp/jq-linux64 /usr/bin/jq && \
    chmod +x /usr/bin/jq && \
    rm -f /tmp/jq-release.key && \
    rm -f /tmp/jq-linux64.asc && \
    rm -f /tmp/jq-linux64

RUN curl -sS https://getcomposer.org/installer | \
            php -- --install-dir=/usr/bin/ --filename=composer

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
