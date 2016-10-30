class ErrorLoop < ServerPlugin
  def name
    'Error Loop'
  end

  def run(client)
    client.on(:error) do |err|
      $stream_log << "Error thrown: #{err.inspect}"
      # TODO: Throw error in return
    end

    stream = client.new_stream
    stream.data('We can has error?')
  end
end