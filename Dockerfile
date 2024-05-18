FROM ubuntu:24.04
MAINTAINER xeroxmalf

# noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive
ENV tz America/Toronto

RUN echo "$tz" > /etc/timezone && \
	apt-get update && \
	apt-get install -y locales pppoe iputils-ping \
	vim-tiny iptables net-tools dnsutils iproute2 && \
	locale-gen en_US.UTF-8 && \
	apt-get clean

ADD start.sh /usr/bin/start.sh
ADD stages/stage1_900.bin /stages/stage1_900.bin
ADD stages/stage1_1100.bin /stages/stage1_1100.bin
ADD stages/stage2_900.bin /stages/stage2_900.bin
ADD stages/stage2_1100.bin /stages/stage2_1100.bin
ADD pppwn /usr/local/bin/pppwn
ENTRYPOINT ["/usr/bin/start.sh"]
