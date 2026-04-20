ARG	VALKEY_MAJOR=9
ARG	DISTRO_NAME=alpine
FROM	valkey/valkey:${VALKEY_MAJOR}-${DISTRO_NAME}
COPY	docker/valkey/valkey.conf	/usr/local/etc/valkey/valkey.conf
CMD	["valkey-server","/usr/local/etc/valkey/valkey.conf"]
