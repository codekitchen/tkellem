require 'openssl'

module Tkellem

class Recaptcha
  def initialize(public_key, private_key)
    @public_key = public_key
    @private_key = private_key
    @secret = ActiveSupport::SecureRandom.hex(16)
  end

  def challenge_url
    "http://www.google.com/recaptcha/mailhide/d?k=#{@public_key}&c=#{url_encoded_secret}"
  end

  def encrypted_secret
    cipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    cipher.encrypt
    cipher.iv = "\x00"*16
    cipher.key = [@private_key].pack("H*") # private key is a hex string
    data = cipher.update(@secret)
    data << cipher.final
    data
  end

  def url_encoded_secret
    [encrypted_secret].pack('m').strip.gsub("\n", '').tr('+/', '-_')
  end

  def valid_response?(response)
    response.strip == @secret
  end
end

end
