FROM ubuntu:24.04
MAINTAINER xeroxmalf

# noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive
ENV tz America/Toronto

RUN echo "$tz" > /etc/timezone && \
	apt-get update && \
	apt-get install -y locales pppoe iputils-ping git wget libpcap-dev cmake \
	build-essential vim-tiny iptables net-tools dnsutils iproute2 unzip && \
	locale-gen en_US.UTF-8 && \
	apt-get clean

COPY start.sh /usr/bin/start.sh
ENTRYPOINT ["/usr/bin/start.sh"]
