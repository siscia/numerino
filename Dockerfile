FROM shanesveller/elixir-lang:1.1.1

MAINTAINER Simone Mosciatti <simone@mweb.biz>

RUN apt-get -qq update

RUN apt-get install -y git

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp

RUN git clone https://github.com/siscia/numerino.git numerino

WORKDIR /numerino

RUN git checkout v0.1.3

RUN mix deps.get

RUN mix compile

EXPOSE 4000

