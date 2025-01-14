require 'cgi'
require 'net/https'
require 'json'

unless defined? Net::HTTP::Patch
  # PATCH support for 1.8.7.
  Net::HTTP::Patch = Class.new(Net::HTTP::Post) { METHOD = 'PATCH' }
end

module GHI
  class Client

    class Error < RuntimeError
      attr_reader :response
      def initialize response
        @response, @json = response, JSON.parse(response.body)
      end

      def body()    @json             end
      def message() body['message']   end
      def errors()  [*body['errors']] end
    end

    class Response
      def initialize response
        @response = response
      end

      def body
        @body ||= JSON.parse @response.body
      end

      def next_page() links['next'] end
      def last_page() links['last'] end

      private

      def links
        return @links if defined? @links
        @links = {}
        if links = @response['Link']
          links.scan(/<([^>]+)>; rel="([^"]+)"/).each { |l, r| @links[r] = l }
        end
        @links
      end
    end

    CONTENT_TYPE = 'application/vnd.github.v3+json'
    USER_AGENT = 'ghi/%s (%s; +%s)' % [
      GHI::Commands::Version::VERSION,
      RUBY_DESCRIPTION,
      'https://github.com/stephencelis/ghi'
    ]
    METHODS = {
      :head   => Net::HTTP::Head,
      :get    => Net::HTTP::Get,
      :post   => Net::HTTP::Post,
      :put    => Net::HTTP::Put,
      :patch  => Net::HTTP::Patch,
      :delete => Net::HTTP::Delete
    }
    DEFAULT_HOST = 'api.github.com'
    HOST = GHI.config('github.host') || DEFAULT_HOST
    PORT = 443

    attr_reader :username, :password
    def initialize username = nil, password = nil
      @username, @password = username, password
    end

    def head path, options = {}
      request :head, path, options
    end

    def get path, params = {}, options = {}
      request :get, path, options.merge(:params => params)
    end

    def post path, body = nil, options = {}
      request :post, path, options.merge(:body => body)
    end

    def put path, body = nil, options = {}
      request :put, path, options.merge(:body => body)
    end

    def patch path, body = nil, options = {}
      request :patch, path, options.merge(:body => body)
    end

    def delete path, options = {}
      request :delete, path, options
    end

    private

    def request method, path, options
      path = "/api/v3#{path}" if HOST != DEFAULT_HOST

      # puts "\n 1#{path}\n"
      # path = CGI.escape path
      # puts "\n 2#{path}\n"

      if params = options[:params] and !params.empty?
        q = params.map { |k, v| "#{CGI.escape k.to_s}=#{CGI.escape v.to_s}" }
        path += "?#{q.join '&'}"
      end

      headers = options.fetch :headers, {}
      headers.update 'Accept' => CONTENT_TYPE, 'User-Agent' => USER_AGENT
      req = METHODS[method].new path, headers
      if GHI::Authorization.token
        req['Authorization'] = "token #{GHI::Authorization.token}"
      end
      if options.key? :body
        req['Content-Type'] = CONTENT_TYPE
        req.body = options[:body] ? JSON.dump(options[:body]) : ''
      end
      req.basic_auth username, password if username && password

      proxy   = GHI.config 'https.proxy', :upcase => false
      proxy ||= GHI.config 'http.proxy',  :upcase => false
      if proxy
        proxy = URI.parse proxy
        http = Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password).new HOST, PORT
      else
        http = Net::HTTP.new HOST, PORT
      end

      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # FIXME 1.8.7

      GHI.v? and puts "\r===> #{method.to_s.upcase} #{path} #{req.body}"
      res = http.start { http.request req }
      GHI.v? and puts "\r<=== #{res.code}: #{res.body}"

      case res
      when Net::HTTPSuccess
        return Response.new(res)
      when Net::HTTPUnauthorized
        if password.nil?
          raise Authorization::Required, 'Authorization required'
        end
      when Net::HTTPMovedPermanently, Net::HTTPTemporaryRedirect
        path = URI.parse(res['location']).path
        return request method, path, options
      end

      raise Error, res
    end
  end
end
