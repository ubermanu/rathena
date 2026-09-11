ARG ALPINE_VERSION=3.23

FROM alpine:${ALPINE_VERSION} AS builder

ARG PACKETVER
ARG PRERE=no
ARG PACKET_OBFUSCATION=no

RUN apk add --no-cache build-base bash zlib-dev mariadb-dev linux-headers

WORKDIR /rathena
COPY . .

# rAthena enables obfuscation for any PACKETVER >= 20110817 and offers no flag to
# turn it off, so the guard is disabled at the source. roBrowser and Korangar both
# require it off.
RUN set -eu; \
    if [ "${PACKET_OBFUSCATION}" = "no" ]; then \
      grep -qE '^[[:space:]]*#ifndef PACKET_OBFUSCATION$' src/config/packets.hpp \
        || { echo "packets.hpp: obfuscation guard not found, upstream layout changed"; exit 1; }; \
      sed -i -E 's|^[[:space:]]*#ifndef PACKET_OBFUSCATION$|    #if 0|' src/config/packets.hpp; \
    fi

RUN ./configure --enable-packetver="${PACKETVER}" --enable-prere="${PRERE}" \
 && make -j"$(nproc)" server

FROM alpine:${ALPINE_VERSION}

ARG PACKETVER
ARG PRERE

RUN apk add --no-cache libstdc++ libgcc zlib mariadb-connector-c bash tzdata

WORKDIR /rathena

COPY --from=builder /rathena/login-server /rathena/char-server /rathena/map-server /rathena/web-server ./
COPY --from=builder /rathena/conf ./conf
COPY --from=builder /rathena/db ./db
COPY --from=builder /rathena/npc ./npc
COPY --from=builder /rathena/sql-files ./sql-files

RUN addgroup -S rathena \
 && adduser -S -G rathena rathena \
 && mkdir -p log save \
 && chown -R rathena:rathena /rathena

USER rathena

ENV RATHENA_PACKETVER=${PACKETVER} \
    RATHENA_PRERE=${PRERE}

EXPOSE 6900 6121 5121 8888

CMD ["./login-server"]
