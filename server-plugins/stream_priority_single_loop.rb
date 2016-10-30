class StreamPrioritySingleLoop < ServerPlugin
  def name
    'Stream Priority Loop (Single)'
  end

  def run(client)
    root_stream = client.new_stream
    stream_two  = client.new_stream(priority: 42, dependency: root_stream.id)
    stream_two.reprioritize(30, stream_two.id)
  end
end
