# frozen_string_literal: true

require 'nylas'
require 'dotenv/load'
require 'sinatra'

set :show_exceptions, :after_handler
enable :sessions

error 404 do
  'No authorization code returned from Nylas'
end

error 500 do
  'Failed to exchange authorization code for token'
end

nylas = Nylas::Client.new(
  api_key: ENV['NYLAS_API_KEY'],
  api_uri: ENV['NYLAS_API_URI']
)

get '/nylas/auth' do
  config = {
    client_id: ENV['NYLAS_CLIENT_ID'],
    provider: 'google',
    redirect_uri: 'http://localhost:4567/oauth/exchange',
    login_hint: 'swag@nylas.com',
    access_type: 'offline',
  }

  url = nylas.auth.url_for_oauth2(config)
  redirect url
end

get '/oauth/exchange' do
  code = params[:code]
  status 404 if code.nil?

  begin
    response = nylas.auth.exchange_code_for_token({
                                                    client_id: ENV['NYLAS_CLIENT_ID'],
                                                    redirect_uri: 'http://localhost:4567/oauth/exchange',
                                                    code: code
                                                  })
  rescue StandardError
    status 500
  else
    response[:grant_id]
    response[:email]
    session[:grant_id] = response[:grant_id]
  end
end

get '/nylas/read-emails' do
  query_params = { limit: 5 }
  messages, = nylas.messages.list(identifier: session[:grant_id], query_params: query_params)
  messages.to_json
rescue StandardError => e
  e.to_s
end

get '/nylas/send-email' do
  request_body = {
    subject: 'Your Subject Here',
    body: 'Your Email Here',
    to: [{ name: 'Name', email: ENV['EMAIL'] }],
    reply_to: [{ name: 'Name', email: ENV['EMAIL'] }]
  }

  email, = nylas.messages.send(identifier: session[:grant_id], request_body: request_body)
  email.to_json
rescue StandardError => e
  e.to_s
end
