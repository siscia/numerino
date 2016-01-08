FROM resin/rpi-raspbian

MAINTAINER Simone Mosciatti

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

RUN apt-get install wget

RUN wget http://packages.erlang-solutions.com/erlang/elixir/FLAVOUR_2_download/elixir_1.1.1-1~raspbian~wheezy_armhf.deb

RUN echo "deb http://packages.erlang-solutions.com/debian wheezy contrib" >> /etc/apt/sources.list

RUN wget http://packages.erlang-solutions.com/debian/erlang_solutions.asc && \
    apt-key add erlang_solutions.asc

RUN apt-get update && apt-get install erlang && apt-get install elixir

RUN git clone https://github.com/siscia/numerino.git numerino

WORKDIR /numerino

RUN git checkout v0.1.4

RUN mix deps.get

RUN mix compile

EXPOSE 4000

