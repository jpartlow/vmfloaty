require 'faraday'
require 'vmfloaty/http'
require 'json'
require 'vmfloaty/errors'

class NSPooler
  def self.list(verbose, url, os_filter=nil)
    conn = Http.get_conn(verbose, url)

    response = conn.get 'status'
    response_body = JSON.parse(response.body)
    response_body.delete('ok')

    os_filter.nil? ?
      hosts = response_body :
      hosts = response_body.select { |k,v| k.match(/#{os_filter}/) }
  
    hosts  
  end

  def self.reserved(verbose, url, user=nil)
    conn = Http.get_conn(verbose, url)

    response = conn.get 'reserved'
    response_body = JSON.parse(response.body)["hosts"]

    user.nil? ?
      response_body :
      response_body.select { |r| r["user"] == user }
  end

  def self._prep(verbose, url, warning, parameter, token)
    raise(MissingParamError, "You must specify the #{warning}") if parameter.nil?
    raise(TokenError, "Token provided was nil. Please obtain a token before checking out nspooler resources.") if token.nil?
    
    conn = Http.get_conn(verbose, url)
    conn.headers['X-AUTH-TOKEN'] = token
    conn
  end

  def self._validate_response(response, parameter, value)
    response_body = JSON.parse(response.body)

    if response.status == 401
      raise(AuthError, "HTTP #{response.status}: The token provided could not authenticate to the pooler.\n#{response_body}")
    elsif response.status == 404
      raise(RuntimeError, "HTTP #{response.status}: Unknown #{parameter}: #{value}\n#{response_body}")
    else
      response_body.delete('ok') if response_body.keys.size > 1
    end

    response_body
  end

  def self.get(verbose, url, os_type, token, reason)
    raise(MissingParamError, "You must specify the reason the host is being reserved") if reason.nil?
    conn = _prep(verbose, url, "type of os to reserve", os_type, token)
    response = conn.post do |req|
      req.url "host"
      req.body = {os_type => 1, "reserved_for_reason" => reason}.to_json
    end

    _validate_response(response, :os_type, os_type)
  end

  def self.release(verbose, url, hostname, token)
    conn = _prep(verbose, url, "hostname to release", hostname, token)
    response = conn.delete "host/#{hostname}"
    _validate_response(response, :hostname, hostname)
  end

  def self.query(verbose, url, hostname)
    raise(MissingParamError, "You must specify the hostname to query") if hostname.nil?
    conn = Http.get_conn(verbose, url)
    response = conn.get "host/#{hostname}"
    _validate_response(response, :hostname, hostname)
  end
end
