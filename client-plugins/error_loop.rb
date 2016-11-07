class ErrorLoopClient < ClientPlugin
  def name
    'Error loop'
  end

  def run(stream, connection, sock)
    connection.on(:goaway) do |err|
      connection.goaway(:internal_error)
    end

    # needed for Safari
=begin
    stream.data('Test', end_stream: false)
    stream.headers({
        'What' => 'test'
    })
=end

    sock.write('Writing random bytes to the raw socket should throw an error')
  end
end