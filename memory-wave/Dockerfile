# syntax=docker/dockerfile:1
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

FROM frolvlad/alpine-gcc
WORKDIR /tmp
COPY wave.c .
RUN gcc --static /tmp/wave.c -Werror -Wall -Wextra -o /tmp/wave

FROM alpine:latest  
WORKDIR /root/
COPY --from=0 /tmp/wave .
ENTRYPOINT ["./wave"]  
