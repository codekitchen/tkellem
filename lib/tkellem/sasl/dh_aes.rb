require 'tkellem/bouncer_connection'
require 'tkellem/sasl/dh'

module Tkellem
module SASL

# Should inherit and implement authorize
class DhAes < DH
  def decrypt(response, sym_key)
    iv, crypted = response.unpack("a16a*")
    cipher = OpenSSL::Cipher.new("AES-#{sym_key.length * 8}-CBC")
    cipher.key_len = sym_key.length
    cipher.decrypt
    cipher.key = sym_key
    cipher.iv = iv
    plain = cipher.update(crypted)
    # need to get the rest out of the buffer, but can't call final cause of non-standard padding
    plain += cipher.update('garbage')
    @authcid, @passwd = plain.unpack("Z*Z*")
  end
end

end
end
