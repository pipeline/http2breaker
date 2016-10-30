class StreamPrioritySingleLoop < ServerPlugin
  def name
    'Stream Priority Loop (Single)'
  end

  def run(client)
    head = {
        ':scheme' => 'https',
        ':method' => 'GET',
        ':authority' => 'nginx.mi1.nz:443',
        ':path' => '/'
    }

    stream = client.new_stream
    stream.headers(head, end_stream: false)
    stream.reprioritize(dependency: stream.id)
    stream.headers({
      'something_else' => 'test'
    }, end_stream: true)
  end
end
