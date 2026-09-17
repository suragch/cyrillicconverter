# Stage 1: Build the CLI app bundle including sqlite3 native assets using modern Dart build hooks
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart build cli -t bin/server.dart -o build/cli/

# Stage 2: Minimal, secure Debian runtime with SQLite3 C library and SSL certs
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the complete compiled bundle (bin/server and lib/libsqlite3.*)
COPY --from=build /app/build/cli/bundle/ /app/

ENV DB_PATH=/data/dictionary.db
ENV PORT=8080

EXPOSE 8080

CMD ["/app/bin/server"]
