FROM ubuntu:20.04 AS buildbase

ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'APT::Acquire::Retries "10";' >> /etc/apt/apt.conf
RUN echo 'APT::Acquire::Queue-Mode "host";' >> /etc/apt/apt.conf
RUN sed -i 's:archive.ubuntu.com/ubuntu/:mirrors.coreix.net/ubuntu/:g' /etc/apt/sources.list
RUN sed -i 's:security.ubuntu.com/ubuntu/:uk.archive.ubuntu.com/ubuntu/:g' /etc/apt/sources.list
RUN apt-get -y update && apt-get full-upgrade -y && apt-get -y install software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update
RUN apt-get -y install build-essential autoconf m4 automake libtool pkg-config git wget curl \
        gcc-9 g++-9 libiberty-dev python3-distutils python3-dev

RUN apt-get -y install gcc-11 g++-11

RUN git clone -v --depth=1 https://github.com/distcc/distcc.git
RUN cd distcc && ./autogen.sh && ./configure && make -j$(nproc) && make install

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN wget https://apt.llvm.org/llvm.sh && chmod +x ./llvm.sh
RUN ./llvm.sh 13

EXPOSE 3632
EXPOSE 3633

RUN useradd distccd
RUN update-distcc-symlinks
USER distccd

ENTRYPOINT /usr/local/bin/distccd --no-detach --daemon --stats --log-level info --log-stderr $OPTIONS

