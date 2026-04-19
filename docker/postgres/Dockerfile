ARG	POSTGRES_MAJOR=18
ARG	DISTRO_NAME=trixie
FROM	postgres:${POSTGRES_MAJOR}-${DISTRO_NAME}
ARG	POSTGRES_MAJOR
COPY	docker/postgres/Aptfile	/tmp/Aptfile
RUN	sed -i "s/\${POSTGRES_MAJOR}/${POSTGRES_MAJOR}/g" /tmp/Aptfile
RUN	apt update -qq \
    && DEBIAN_FRONTEND=noninteractive apt install -yq --no-install-recommends $(grep -Ev '^\s*#' /tmp/Aptfile | xargs) \
    && apt clean \
    && apt autoclean \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/Aptfile /var/log/apt/* /var/log/alternatives.log /var/cache/apt/archives/*
COPY	docker/postgres/postgresql.conf	/etc/postgresql/postgresql.conf
CMD	["/usr/local/bin/docker-entrypoint.sh","postgres","-c","config_file=/etc/postgresql/postgresql.conf"]
