require 'tkellem/bouncer_connection'
require 'tkellem/sasl/dh'

module Tkellem
module SASL

# Should inherit and implement authorize
class DhBlowfish < DH
  def decrypt(response, sym_key)
    @authcid, crypted_passwd = response.unpack("Z*a*")
    cipher = OpenSSL::Cipher.new("BF-ECB")
    cipher.key_len = sym_key.length
    cipher.decrypt
    cipher.key = sym_key
    @passwd = cipher.update(crypted_passwd)
  end
end

end
end