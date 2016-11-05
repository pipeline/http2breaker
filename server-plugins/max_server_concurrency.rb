class MaxServerConcurrency < ServerPlugin
  def name
    'Maximum Concurrency'
  end

  def run(client)
    head = {
        ':scheme' => 'https',
        ':method' => 'POST',
        ':authority' => 'nginx.mi1.nz:443',
        ':path' => '/',
        'content_length' => "#{1024*101}"
    }

    max_streams = client.remote_settings[:settings_max_concurrent_streams]
    max_streams += 50

    for i in 0..max_streams
      head[':path'] = "/#{i}"
      stream = client.new_stream
      stream.headers(head, end_stream: false)
      stream.data('A')
    end
  end
end