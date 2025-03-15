# syntax=docker/dockerfile:1
FROM alpine AS base

ENV TERM=xterm-kitty \
    LANG=en_US.UTF8

RUN --mount=type=cache,target=/var/cache/apk \
	/bin/sh -c set -ex && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add  \
        apache2-utils \
        bash \
        bind-tools \
        bird \
        bridge-utils \
        busybox-extras \
        conntrack-tools \
        curl \
        dhcping \
        drill \
        ethtool \
        file \
        fping \
        iftop \
        iperf \
        iperf3 \
        iproute2 \
        ipset \
        iptables \
        iptraf-ng \
        iputils \
        ipvsadm \
        httpie \
        jq \
        libc6-compat \
        liboping \
        ltrace \
        mtr \
        net-snmp-tools \
        netcat-openbsd \
        nftables \
        ngrep \
        nmap \
        nmap-nping \
        nmap-scripts \
        openssl \
        py3-pip \
        py3-setuptools \
        scapy \
        socat \
        speedtest-cli \
        openssh \
        strace \
        tcpdump \
        tcptraceroute \
        tshark \
        util-linux \
        vim \
        git \
        zsh \
        websocat \
        swaks \
        perl-crypt-ssleay \
        perl-net-ssleay \
		btop \
		kitty-terminfo \
		fzf \
		sudo \
		ctop \
		termshark \
		grpcurl \
        zip \
        coreutils \
        e2fsprogs \
        gptfdisk

RUN bash <<EOF

set -ex

curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended

git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/romkatv/powerlevel10k.git /root/.oh-my-zsh/custom/themes/powerlevel10k
git clone --depth 1 https://github.com/zsh-users/zsh-completions /root/.oh-my-zsh/custom/plugins/zsh-completions
git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting /root/.oh-my-zsh/custom/plugins/fast-syntax-highlighting


EOF

COPY zshrc /root/.zshrc
COPY p10k.zsh /root/.p10k.zsh
COPY --chmod=755 transfer.sh /usr/local/bin/transfer.sh

WORKDIR /root

CMD [ "bash", "-c", "zsh; exit 0" ]

FROM base AS docker

RUN --mount=type=cache,target=/var/cache/apk \
    apk add docker-cli docker-cli-buildx docker-zsh-completion docker-cli-compose

FROM base AS nerdctl

RUN --mount=type=cache,target=/var/cache/apk \
    apk add nerdctl

FROM base AS podman

RUN --mount=type=cache,target=/var/cache/apk \
    apk add podman fuse-overlayfs

COPY podman-storage.conf /root/.config/containers/storage.conf

