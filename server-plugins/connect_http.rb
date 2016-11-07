class ConnectHTTP < ServerPlugin
  def name
    'Connect (HTTP)'
  end

  def run(client, host)
    head = {
        ':method' => 'CONNECT',
        ':authority' => host
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
