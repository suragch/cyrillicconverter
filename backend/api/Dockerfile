# Stage 1: Build the application
FROM google/dart:stable AS build

WORKDIR /app

# Copy pubspec and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code
COPY . .

# Compile the application
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Create the runtime image
FROM debian:stable-slim

WORKDIR /app

# Copy the compiled executable from the build stage
COPY --from=build /app/bin/server /app/bin/server

# Expose the port the app runs on
EXPOSE 8080

# Define the command to run the executable
CMD ["/app/bin/server"]
