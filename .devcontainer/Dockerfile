FROM mcr.microsoft.com/devcontainers/universal:2

# Install ab
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
    apache2-utils \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install alp
RUN curl -L -O https://github.com/tkuchiki/alp/releases/download/v1.0.12/alp_linux_amd64.tar.gz \
  && tar -zxvf alp_linux_amd64.tar.gz \
  && sudo install alp /usr/local/bin/alp
