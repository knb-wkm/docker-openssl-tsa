require "sinatra"
require "tempfile"

set :port, 8888
set :bind, '0.0.0.0'

post '/tsa' do
  openssl = "/usr/bin/openssl"
  openssl_root = "/openssl-tsa"

  Tempfile.create("./tsatmp") do |f|
    f.binmode
    f.write request.body.read
    f.rewind
    content_type "application/timestamp-reply"
    `cd #{openssl_root} && #{openssl} ts -reply -config openssl.cnf -queryfile #{f.path} -inkey tsa.key -signer tsa.crt`    
  end

end
