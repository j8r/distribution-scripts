FROM alpine:3.6

ADD julien@portalier.com-56dab02e.rsa.pub /etc/apk/keys/

# Install dependencies
RUN echo "http://public.portalier.com/alpine/testing" >> /etc/apk/repositories \
 \
 && apk upgrade --update \
 && apk add --update \
      # Crystal to compile crystal with
      crystal \
      # Statically-compiled llvm
      llvm4-dev llvm4-static \
      # Static zlib
      zlib-dev \
      # Build tools
      git gcc g++ make automake libtool autoconf bash

# Build libgc (gc and libatomic_ops version are master as of 2017-08-22)
ARG gc_version=119a2a5e58d982ba2a6b10781b13bbcc9ccaf160
ARG libatomic_ops_version=3265147277bfb7462ab9d190982ace17ea06b640
RUN git clone https://github.com/ivmai/bdwgc \
 && cd bdwgc \
 && git checkout ${gc_version} \
 && git clone https://github.com/ivmai/libatomic_ops \
 && (cd libatomic_ops && git checkout ${libatomic_ops_version}) \
 \
 && ./autogen.sh \
 && ./configure --disable-shared \
 && make CFLAGS=-DNO_GETCONTEXT

# Build libevent
ARG libevent_version=release-2.1.8-stable
RUN git clone https://github.com/libevent/libevent \
 && cd libevent \
 && git checkout ${libevent_version} \
 \
 && ./autogen.sh \
 && ./configure --disable-shared \
 && make

# Build crystal
ARG crystal_version=4e09b6bb4563845b7123f131413c09e8172b8b23
RUN git clone https://github.com/RX14/crystal \
 && cd crystal \
 && git checkout ${crystal_version} \
 \
 # NOTE: don't need to compile our own compiler after next release
 && make crystal doc \
 && env CRYSTAL_CONFIG_VERSION=${crystal_version} CRYSTAL_CONFIG_TARGET=x86_64-unknown-linux-gnu \
      bin/crystal build --stats --link-flags="-L/bdwgc/.libs/ -L/libevent/.libs/" \
      src/compiler/crystal.cr -o crystal -D without_openssl -D without_zlib --static

ADD crystal-wrapper /output/bin/crystal

RUN \
 # Copy libgc.a to /lib/crystal/lib/
    mkdir -p /output/lib/crystal/lib/ \
 && cp /bdwgc/.libs/libgc.a /output/lib/crystal/lib/libgc.a \
 \
 # Copy libgc.a to /lib/crystal/lib/
 && mkdir -p /output/lib/crystal/bin/ \
 && cp /crystal/crystal /output/lib/crystal/bin/crystal \
 \
 # Copy stdlib to /share/crystal/src/
 && mkdir -p /output/share/crystal/ \
 && cp -r /crystal/src /output/share/crystal/src \
 \
 # Copy html docs and samples
 && mkdir -p /output/share/doc/crystal/ \
 && cp -r /crystal/doc /output/share/doc/crystal/api \
 && cp -r /crystal/samples /output/share/doc/crystal/samples \
 \
 # Copy manpage
 && mkdir -p /output/share/man/man1/ \
 && cp /crystal/man/crystal.1 /output/share/man/man1/crystal.1 \
 \
 # Copy license
 && mkdir -p /output/share/licenses/crystal/ \
 && cp /crystal/LICENSE /output/share/licenses/crystal/LICENSE \
 \
 # Create tarball
 && mv /output /crystal-${crystal_version} \
 && mkdir /output \
 && tar -cvf /output/crystal-${crystal_version}.tar /crystal-${crystal_version}