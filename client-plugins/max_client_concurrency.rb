class MaxClientConcurrency < ClientPlugin
  def name
    'Maximum Concurrency'
  end

  def run(stream, connection, sock)
    max_streams = connection.remote_settings[:settings_max_concurrent_streams]
    max_streams += 50

    connection.set_remote_max_streams(max_streams)

    push_promise_headers = {
        ':method' => 'GET',
        ':scheme' => 'https',
        ':path'   => '/stylesheet.css',
        ':authority' => 'localhost:8080'
    }

    stream.headers({
      ':status' => '200',
      'content-length' => "#{max_streams}",
      'content-type' => 'text/html'
    }, end_stream: false)

    for i in 0..max_streams
      push_promise_headers[':path'] = "/stylesheet_#{i}.css"
      stream.promise(push_promise_headers, end_headers: true) do |prom|
      end

      stream.data('A', end_stream: false)
    end
  end
end