FROM almalinux:latest

LABEL org.opencontainers.image.source="https://github.com/iamangus/term"
LABEL org.opencontainers.image.description="AlmaLinux SSH dev box with OpenChamber web UI"

ENV TZ="America/Chicago"
ENV k9s_VER="0.50.16"
ENV SOPS_VER="3.8.1"
ENV HOSTNAME="devbox"

COPY kubernetes.repo /etc/yum.repos.d/kubernetes.repo 

RUN dnf update -y && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf install -y https://github.com/derailed/k9s/releases/download/v$k9s_VER/k9s_linux_amd64.rpm && \
    dnf install -y https://github.com/getsops/sops/releases/download/v$SOPS_VER/sops-$SOPS_VER.x86_64.rpm && \
    dnf install -y epel-release && \
    dnf install -y curl && \
    curl -fsSL https://rpm.nodesource.com/setup_23.x | bash - && \
    dnf install -y nodejs && \
    dnf install -y --setopt=install_weak_deps=False \
      vim ipmitool kubectl openssh-server opentofu sudo gh git zsh util-linux-user golang procps-ng \
      make jq yq htop tmux gcc gcc-c++ python3 python3-pip tree file rsync bind-utils nmap-ncat curl wget && \
    dnf install -y --setopt=install_weak_deps=False \
      chromium chromium-headless nss atk at-spi2-atk libXcomposite libXcursor libXdamage libXext libXi libXtst \
      cups-libs libXScrnSaver libXrandr alsa-lib pango at-spi2-core libXt mesa-libgbm && \
    dnf clean all && rm -rf /var/cache/dnf

RUN npm install -g @openchamber/web

RUN ssh-keygen -A

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

EXPOSE 22 3000 4096

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD pgrep sshd || exit 1

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
