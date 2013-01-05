module Tkellem

class ListenAddress < Sequel::Model
  plugin :validation_class_methods

  validates_uniqueness_of :port, :scope => [:address]
  validates_presence_of :address, :port

  def to_s
    "#{ssl ? 'ircs' : 'irc'}://#{address}:#{port}"
  end

  def after_create
    super
    $tkellem_server.try(:after_create, self)
  end

  def after_destroy
    super
    $tkellem_server.try(:after_destroy, self)
  end
end

end
