FROM ubuntu:24.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      --no-install-recommends \
      iverilog verilator yosys coreutils bash ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /out
