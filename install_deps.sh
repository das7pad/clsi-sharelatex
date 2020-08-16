#!/bin/sh

apt-get update && \
  \
  apt-get install --yes \
      poppler-utils \
      ghostscript \
      qpdf \
  \
&& rm -rf /var/lib/apt/lists/*

# https://stackoverflow.com/questions/52998331/imagemagick-security-policy-pdf-blocking-conversion#comment110879511_59193253
# License: CC BY-SA 4.0
sed -i '/disable ghostscript format types/,+6d' /etc/ImageMagick-6/policy.xml
