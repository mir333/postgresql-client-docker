FROM alpine
RUN apk --no-cache add postgresql17-client
ENTRYPOINT [ "psql" ]
