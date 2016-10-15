require 'http/2'
require 'optparse'
require 'socket'
require 'openssl'

DRAFT = 'h2'.freeze

require './client-plugins/client_plugin.rb'

Dir['client-plugins/*.rb'].each { |file|
  next if file == 'client-plugins/client_plugin.rb'
  require "./#{file}"
}

plugins = []
ClientPlugin.plugins.each do |plugin|
  plugins << eval("#{plugin}.new")
end

class Logger
  def initialize(id)
    @id = id
  end

  def info(msg)
    puts "[Stream #{@id}]: #{msg}"
  end
end

options = { port: 8080 }
OptionParser.new do |opts|
  opts.banner = 'Usage: server.rb [options]'

  opts.on('-i', '--insecure', 'Do not use HTTPS (experimental)') do |v|
    options[:insecure] = v
  end

  opts.on('-p', '--port [Integer]', 'listen port') do |v|
    options[:port] = v
  end
end.parse!

unless options[:insecure]
  puts "Starting server on port #{options[:port]}"
  server = TCPServer.new(options[:port])

  ctx = OpenSSL::SSL::SSLContext.new
  ctx.cert = OpenSSL::X509::Certificate.new(File.open('keys/server.crt'))
  ctx.key = OpenSSL::PKey::RSA.new(File.open('keys/server.key'))

  ctx.ssl_version = :TLSv1_2
  ctx.options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
  ctx.ciphers = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]

  ctx.alpn_select_cb = lambda do |protocols|
    raise "Protocol #{DRAFT} is required" if protocols.index(DRAFT).nil?
    DRAFT
  end

  # this is necessary for older versions of Ruby
  #ctx.tmp_ecdh_callback = lambda do |_args|
  #  key = OpenSSL::PKey::EC.new 'prime256v1'
  #  key.generate_key
  #  key
  #end

  ctx.ecdh_curves = "P-256"

  server = OpenSSL::SSL::SSLServer.new(server, ctx)
end

loop do
  sock = server.accept
  puts 'New TCP connection!'

  conn = HTTP2::Server.new
  conn.on(:frame) do |bytes|
    # puts "Writing bytes: #{bytes.unpack("H*").first}"
    sock.write bytes
  end
  conn.on(:frame_sent) do |frame|
    puts "Sent frame: #{frame.inspect}"
  end
  conn.on(:frame_received) do |frame|
    puts "Received frame: #{frame.inspect}"
  end

  conn.on(:stream) do |stream|
    log = Logger.new(stream.id)
    req, buffer = {}, ''

    stream.on(:active) { log.info 'client opened new stream' }
    stream.on(:close)  { log.info 'stream closed' }

    stream.on(:headers) do |h|
      req = Hash[*h.flatten]
      log.info "request headers: #{h}"
    end

    stream.on(:data) do |d|
      log.info "payload chunk: <<#{d}>>"
      buffer << d
    end

    stream.on(:half_close) do
      log.info 'client closed its end of the stream'

      if req[':method'] == 'POST'
        log.info "Received POST request, payload: #{buffer}"
        response = "Hello HTTP 2.0! POST payload: #{buffer}"
      else
        log.info 'Received GET request'
      end

      found = false
      if req[':path'] == '/'
        found = true
        response = ''
        plugins.each do |plugin|
          response += "<a href=\"/#{plugin.class.name}\">#{plugin.name}</a><br>"
        end

        stream.headers({
          ':status' => '200',
          'content-length' => response.bytesize.to_s,
          'content-type' => 'text/html'
        }, end_stream: false)

        # split response into multiple DATA frames
        stream.data(response.slice!(0, 5), end_stream: false)
        stream.data(response)
      end

      path = req[':path'][1..-1] # remove the preceeding slash

      plugins.each do |plugin|
        if path == plugin.class.name
          found = true
          plugin.run(stream)
        end
      end

      unless found
        stream.headers({':status' => '404'}, end_headers: true, end_stream: true)
      end
    end
  end

  while !sock.closed? && !(sock.eof? rescue true) # rubocop:disable Style/RescueModifier
    data = sock.readpartial(1024)
    # puts "Received bytes: #{data.unpack("H*").first}"

    begin
      conn << data
    rescue => e
      puts "#{e.class} exception: #{e.message} - closing socket."
      e.backtrace.each { |l| puts "\t" + l }
      sock.close
    end
  end
end
