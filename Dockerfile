#################
## build stage ##
#################
FROM rust:1.68.1-bullseye AS builder
WORKDIR /code

# Download crates-io index and fetch dependency code.
# This step avoids needing to spend time on every build downloading the index
# which can take a long time within the docker context. Docker will cache it.
RUN USER=root cargo init
COPY Cargo.toml Cargo.toml
COPY Cargo.lock Cargo.lock
RUN cargo fetch

# copy app files
COPY src src
COPY migrations migrations
COPY static static

# compile app
RUN cargo build --release

###############
## run stage ##
###############
FROM debian:bullseye-20211220
# FROM debian:bullseye-20230411
WORKDIR /app

RUN USER=root apt update -y
RUN USER=root apt install libpq5 -y

# copy server binary from build stage
COPY --from=builder /code/target/release/azure-voting-app-rust azure-voting-app-rust
COPY static static

# set user to non-root unless root is required for your app
USER 1001

# indicate what port the server is running on
ENV PORT 8080
EXPOSE 8080

# run server
CMD [ "/app/azure-voting-app-rust" ]
