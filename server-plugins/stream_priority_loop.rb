class StreamPriorityLoop < ServerPlugin
  def name
    'Stream Priority Loop'
  end

  def run(client)
    root_stream = client.new_stream
    stream_two  = client.new_stream(priority: 42, dependency: root_stream.id)
    stream_three = client.new_stream(priority: 30, dependency: stream_two.id)
    stream_two.reprioritize(30, stream_three.id)

    # what if we make stream 4 dependent on itself?
  end
end