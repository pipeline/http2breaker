# TODO:
#    * Create first DOS endpoint

class ServerPlugin
  def self.plugins
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

  def self.run_plugin(url, pluginName)
    plugin_run = false
    conn = nil
    self.plugins.each do |plugin|
      plugin = eval("#{plugin}.new")
      if pluginName == plugin.class.name
        conn = plugin.run(create_connection(url))
        plugin_run = true
      end
    end

    if plugin_run
      min_time = Time.now.to_i + 5
      while !$sock.closed? && Time.now.to_i <= min_time
        puts "Selecting"
        result = select([$sock], nil, nil, 5)

        #puts result.inspect

        if result
          data = $sock.readpartial(1024000)
          min_time = Time.now.to_i + 5

          begin
            puts "CLIENT DATA Received bytes: #{data.unpack("H*").first}"
            $conn << data
          rescue => e
            puts "#{e.class} exception: #{e.message} - closing socket."
            e.backtrace.each { |l| puts "\t" + l }
            $sock.close
          end
        else
          #puts "SOCKET TIMEED OUT!"
          $sock.close
          break
        end
      end

      $sock.close

      return $server_log
    end

    return nil
  end

  private

  def self.create_connection(url)
    uri = URI.parse(url)
    tcp = TCPSocket.new(uri.host, uri.port)

    $sock = nil
    log = Logger.new(-1)
    $server_log = []

    #$server_log << { endpoint: 'message', message: "Creating connection to: #{uri}" }

    if uri.scheme == 'https'
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

      ctx.npn_protocols = [DRAFT]
      ctx.npn_select_cb = lambda do |protocols|
        puts "NPN protocols supported by server: #{protocols}"
        DRAFT if protocols.include? DRAFT
      end

      $sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      $sock.sync_close = true
      $sock.hostname = uri.hostname
      $sock.connect

      if $sock.npn_protocol != DRAFT
        puts "Failed to negotiate #{DRAFT} via NPN"
        exit
      end
    else
      $sock = tcp
    end

    $conn = HTTP2::Client.new

    $conn.on(:frame) do |bytes|
      #puts "SOCKET Sending bytes: #{bytes.unpack("H*").first}"
      $sock.print bytes
      $sock.flush
    end
    $conn.on(:frame_sent) do |frame|
      $server_log << { direction: 'Outbound', message: "#{frame.inspect}" }
      log.info "Sent: #{frame.inspect}"
    end
    $conn.on(:frame_received) do |frame|
      $server_log << { direction: 'Inbound', message: "#{frame.inspect}"}
      log.info "Received: #{frame.inspect}"
    end

    $conn.on(:promise) do |promise|
      promise.on(:headers) do |h|
        log.info "promise headers: #{h}"
      end

      promise.on(:data) do |d|
        log.info "promise data chunk: <<#{d.size}>>"
      end
    end

    $conn.on(:altsvc) do |f|
      log.info "received ALTSVC #{f}"
    end

    $conn
  end

end
