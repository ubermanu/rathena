FROM alpine:3.11 as builder
WORKDIR /rathena
RUN apk add --no-cache make gcc g++ zlib-dev mariadb-dev linux-headers
COPY . .
RUN ./configure
RUN make clean server

FROM alpine:3.11
RUN apk add --no-cache libgcc libstdc++ gcompat mariadb-connector-c
COPY --from=builder /rathena /rathena
WORKDIR /rathena
CMD ["./athena-start watch"]
