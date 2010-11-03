begin
  require 'rubygems'
rescue LoadError
end
require 'eventmachine'

pathname = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push(pathname) unless $LOAD_PATH.include?(pathname)

require 'tkellem/listener'
