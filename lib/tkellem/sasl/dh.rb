require 'tkellem/bouncer_connection'
require 'tkellem/sasl/base'

module Tkellem
  module SASL

# Should inherit and implement authorize
    class DH < Base
      attr_reader :passwd

      def self.dh
        @dh ||= OpenSSL::PKey::DH.generate(256, 5)
      end

      def response(response)
        if !response
          @dh = OpenSSL::PKey::DH.new(DH.dh.to_der)
          @dh.generate_key!
          p, g, y = @dh.p.to_s(2), @dh.g.to_s(2), @dh.pub_key.to_s(2)
          [p.bytesize, p, g.bytesize, g, y.bytesize, y].pack('na*na*na*')
        elsif !@dh
          # never sent a challenge?
          nil
        else
          pub_key_len = response.slice!(0...2).unpack('n').first
          pub_key = response.slice!(0...pub_key_len)
          sym_key = @dh.compute_key(OpenSSL::BN.new(pub_key, 2))
          decrypt(response, sym_key)
          unless authenticate
            @authcid, @passwd = nil
          end

          nil
        end
      end
    end

  end
end