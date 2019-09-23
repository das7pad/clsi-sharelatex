#!/bin/sh

apt-get update && \
  \
  apt-get install --yes \
      poppler-utils \
      ghostscript \
      qpdf \
  \
&& rm -rf /var/lib/apt/lists/*
