class ErrorLoop < ServerPlugin
  def name
    'Error Loop'
  end

  def run(client, host)
    client.on(:goaway) do |err|
      $server_log << { direction: 'info', message: "Error thrown: #{err.inspect}" }
      client.goaway(:internal_error)
    end

    head = {
        ':scheme' => 'https',
        ':method' => 'GET',
        ':authority' => host,
        ':path' => '/'
    }

    # this will throw an error, but there's probably a nicer way to do it
    stream = client.new_stream
    stream.headers(head, end_stream: false)
    stream.reprioritize(dependency: stream.id)
    stream.headers({
      'something_else' => 'test'
    }, end_stream: true)
  end
end