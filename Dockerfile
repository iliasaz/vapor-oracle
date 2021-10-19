# ================================
# Build image
# ================================
FROM swiftora as build

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build -c release -Xlinker -L/usr/local/lib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Run" ./

# Copy any resouces from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM swift:focal-slim

# Make sure all system packages are up to date.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*

RUN apt update
RUN apt-get install -y libaio1 libfreetype6-dev


# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

env ORACLE_HOME=/app/instantclient
env TNS_ADMIN=$ORACLE_HOME/network/admin
env LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME:/usr/local/lib
env PATH=$PATH:$ORACLE_HOME

RUN export ORACLE_HOME
RUN export TNS_ADMIN
RUN export LD_LIBRARY_PATH
RUN export PATH

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app
COPY --from=build $ORACLE_HOME $ORACLE_HOME/
COPY --from=build /usr/local/lib /usr/local/lib/

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start this service on 8080
ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
