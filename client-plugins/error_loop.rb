class ErrorLoopClient < ClientPlugin
  def name
    'Error loop'
  end

  def run(stream, connection, sock)
    connection.on(:goaway) do |err|
      connection.goaway(:internal_error)
    end

    sock.write('Writing random bytes to the raw socket should throw an error')
  end
end