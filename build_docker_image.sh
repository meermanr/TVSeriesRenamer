#!/bin/bash
docker buildx build -t meermanr/tvrenamer:${1-latest} .
