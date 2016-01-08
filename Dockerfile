FROM armv7/armhf-ubuntu_core:14.04.2

MAINTAINER Simone Mosciatti <simone@mweb.biz>

WORKDIR /

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -q && \
    apt-get -y install curl locales wget libssl-dev ncurses-dev git && \
    locale-gen "en_US.UTF-8" && \
    export LANG=en_US.UTF-8 && \
    wget http://www.erlang.org/download/otp_src_18.2.1.tar.gz && \
    tar -xzvf otp_src_18.2.1.tar.gz

WORKDIR otp_src_18.2.1/

RUN ./configure && \
    make
    make install

WORKDIR /

RUN rm -R otp_src_18.2.1/

ENV LANG=en_US.UTF-8

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp

RUN git clone https://github.com/elixir-lang/elixir.git elixir

WORKDIR /elixir

RUN git checkout v1.1.1

RUN make clean test

RUN git clone https://github.com/siscia/numerino.git numerino

WORKDIR /numerino

RUN git checkout v0.1.3

RUN mix deps.get

RUN mix compile

EXPOSE 4000

