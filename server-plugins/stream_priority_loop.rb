class StreamPriorityLoop < ServerPlugin
  def name
    'Stream Priority Loop'
  end

  def run(client)
    head = {
        ':scheme' => 'https',
        ':method' => 'GET',
        ':authority' => 'nginx.mi1.nz:443',
        ':path' => '/'
    }

    stream_two  = client.new_stream
    stream_two.headers(head, end_stream: false)

    stream_three = client.new_stream
    stream_three.reprioritize(dependency: stream_two.id)
    stream_three.headers(head, end_stream: true)

    stream_two.reprioritize(dependency: stream_three.id)
    stream_two.headers({
        'something_else' => 'test'
    }, end_stream: true)
  end
end
