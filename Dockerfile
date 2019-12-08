# final stage
FROM alpine:3.9.4
WORKDIR /app
COPY . /app/
RUN ["chmod", "+x", "newtest"]
ENTRYPOINT ./newtest
