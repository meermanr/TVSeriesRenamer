#!/bin/bash
docker run \
    --rm \
    -it \
    -v "$PWD:$PWD" \
    -w "$PWD" \
    tvrenamer \
    "${@}"
