FROM ubuntu:20.04 AS buildbase

ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'APT::Acquire::Retries "10";' >> /etc/apt/apt.conf
RUN echo 'APT::Acquire::Queue-Mode "host";' >> /etc/apt/apt.conf
RUN sed -i 's:archive.ubuntu.com/ubuntu/:mirrors.coreix.net/ubuntu/:g' /etc/apt/sources.list
RUN sed -i 's:security.ubuntu.com/ubuntu/:uk.archive.ubuntu.com/ubuntu/:g' /etc/apt/sources.list
RUN apt-get -y update && apt-get full-upgrade -y && apt-get -y install software-properties-common
RUN apt-get -y install build-essential autoconf m4 automake libtool pkg-config git wget curl \
        libiberty-dev python3-distutils python3-dev libavahi-core-dev gcc-multilib

FROM buildbase as build_toolchains

#
# Build gcc-4.8.5 for compat with Centos 7
#
RUN wget https://ftp.gnu.org/gnu/gcc/gcc-4.8.5/gcc-4.8.5.tar.bz2 --no-check-certificate
RUN tar xf gcc-4.8.5.tar.bz2
RUN cd gcc-4.8.5 && ./contrib/download_prerequisites
RUN sed -i -e 's/__attribute__/\/\/__attribute__/g' gcc-4.8.5/gcc/cp/cfns.h
RUN sed -i 's/struct ucontext/ucontext_t/g' gcc-4.8.5/libgcc/config/i386/linux-unwind.h
RUN mkdir xgcc-4.8.5
RUN cd xgcc-4.8.5 && ../gcc-4.8.5/configure --enable-languages=c,c++ --prefix=/usr --disable-shared --program-suffix=-4.8.5 --disable-libsanitizer
RUN cd xgcc-4.8.5 && make -j$(nproc)
RUN cd xgcc-4.8.5 && make DESTDIR=$(pwd)/out install
RUN git clone -v --depth=1 https://github.com/distcc/distcc.git
RUN cd distcc && ./autogen.sh && ./configure && make -j$(nproc) && make DESTDIR=$(pwd)/out install

FROM buildbase AS build-farm

#
# GCC toolchains
#
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt-get update && apt-get -y install \
        gcc-7 g++-7 \
        gcc-8 g++-8 \
        gcc-9 g++-9 \
        gcc-10 g++-10 \
        gcc-11 g++-11

COPY --from=build_toolchains /xgcc-4.8.5/out /

#
# Clang toolchains.
#
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN wget https://apt.llvm.org/llvm.sh && chmod +x ./llvm.sh
RUN ./llvm.sh 10
RUN ./llvm.sh 11
RUN ./llvm.sh 12
RUN ./llvm.sh 13


#
# Distcc
#
COPY --from=build_toolchains /distcc/out /

EXPOSE 3632
EXPOSE 3633

RUN useradd distccd
RUN update-distcc-symlinks
USER distccd

ENTRYPOINT /usr/local/bin/distccd --no-detach --daemon --stats --log-level info --log-stderr $OPTIONS

