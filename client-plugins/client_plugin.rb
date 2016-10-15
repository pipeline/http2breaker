class ClientPlugin
  def self.plugins
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end
end
