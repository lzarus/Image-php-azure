FROM 20-buster-slim AS lzarus_upstream
LABEL maintainer="Update by Hasiniaina Andriatsiory <hasiniaina.andriatsiory@gmail.com>"

FROM lzarus_upstream AS lzarus_node
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && \
	apt-get install --force-yes -y --no-install-recommends \
	ca-certificates apt-transport-https openssh-server apache2 curl cron telnet vim

ENV SSH_PORT 2222
EXPOSE 2222 
COPY sshd_config /etc/ssh/
#clean
RUN apt-get clean && rm -rf /var/cache/apt/lists

# configure startup
COPY sshd_config /etc/ssh/
COPY ssh_setup.sh /tmp
RUN service ssh restart