FROM ubuntu:16.04

WORKDIR /app

# openssl, ruby sinatraで利用するディレクトリを作成しておく
RUN set -x && mkdir /openssl-tsa && mkdir /openssl-tsa/config

# opensslで必要なファイル
COPY openssl-tsa/openssl.cnf /openssl-tsa
COPY openssl-tsa/extKey.cnf /openssl-tsa
COPY openssl-tsa/config/tsa.cnf /openssl-tsa/config
COPY openssl-tsa/config/tsaroot.cnf /openssl-tsa/config

# ruby sinatraで必要なファイル
COPY app/Gemfile /app
COPY app/app.rb /app

RUN set -x && \
    cd /openssl-tsa && \
    apt-get update && \
    apt-get install -y git vim curl && \
    openssl genrsa -out tsaroot.key 2048 -config openssl.cnf && \
    openssl req -new -x509 -key tsaroot.key -out tsaroot.crt -config config/tsaroot.cnf && \
    openssl genrsa -out tsa.key 2048 -config openssl.cnf && \
    openssl req -new -key tsa.key -out tsa.csr -config config/tsa.cnf && \
    openssl x509 -req -days 730 -in tsa.csr -CA tsaroot.crt -CAkey tsaroot.key -set_serial 01 -out tsa.crt -extfile extKey.cnf && \
    apt-get install -y autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev && \
    cd && \
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    cd ~/.rbenv && src/configure && make -C src && \
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile && \
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile && \
    . ~/.bash_profile && \
    mkdir -p "$(rbenv root)"/plugins && \
    git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build && \
    rbenv install 2.6.1 && \
    rbenv rehash && \
    rbenv local 2.6.1

CMD bash -c "/root/.rbenv/bin/rbenv local 2.6.1 && /root/.rbenv/shims/bundle install && /root/.rbenv/shims/ruby app.rb"

EXPOSE 8888    
# トークン作成
# openssl ts -query -data openssl.cnf -sha256 -no_nonce -cert -config openssl.cnf -policy 1.3.76.36.1.1.41 -out openssl.cnf.tsq

# トークンをテキストで
# openssl ts -query -in openssl.cnf.tsq -text
# openssl ts -reply -config openssl.cnf -queryfile openssl.cnf.tsq -inkey tsa.key -signer tsa.crt -out openssl.cnf.tsr
# openssl ts -reply -in openssl.cnf.tsr -text
# openssl ts -verify -queryfile openssl.cnf.tsq -in openssl.cnf.tsr -CAfile tsaroot.crt -untrusted tsa.crt

# curl -H "Content-Type: application/timestamp-query" --data-binary @openssl.cnf.tsq http://localhost:8888/tsa

# /usr/bin/openssl ts -reply -config /openssl-tsa/openssl.cnf -queryfile /openssl-tsa/openssl.cnf.tsq -inkey /openssl-tsa/tsa.key -signer /openssl-tsa/tsa.crt