# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'sinatra'

require_relative '../../lib/sinatra/router'

# suppress Sinatra
set :run, false

Apps = (0..3).map do |i|
  Sinatra.new do
    set :raise_errors, true
    set :show_exceptions, false
    enable :method_override

    get "/app#{i}" do
      headers['X-Cascade'] = 'pass' if params[:pass] == 'true'
      200
    end
  end
end

AppWithMethodOverride =
  Sinatra.new do
    set :method_override, true
  end

App =
  Sinatra.new do
    set :method_override, false
  end

# generates a condition lambda suitable for testing
def condition(identifier)
  ->(e) { e["HTTP_X_COND#{identifier}"] == 'true' }
end

describe Sinatra::Router do
  include Rack::Test::Methods

  describe 'as a rack app' do
    def app
      Sinatra::Router.new do
        mount Apps[0]
        mount Apps[1], condition(1)

        with_conditions(condition(2)) do
          mount Apps[2]
          with_conditions(condition(3)) { mount Apps[3] }
        end

        run ->(_env) { [404, {}, []] }
      end
    end

    it 'routes to an app' do
      get '/app0'
      assert_equal 200, last_response.status
    end

    it 'responds with 404' do
      get '/not-found'
      assert_equal 404, last_response.status
    end

    it 'passes through apps' do
      get '/app0', pass: true
      assert_equal 404, last_response.status
    end

    it 'passes routing conditions' do
      header 'X-Cond1', 'true'
      get '/app1'
      assert_equal 200, last_response.status
    end

    it 'fails routing conditions' do
      get '/app1'
      assert_equal 404, last_response.status
    end

    it 'passes routing conditions in a block' do
      header 'X-Cond2', 'true'
      get '/app2'
      assert_equal 200, last_response.status
    end

    it 'fails routing conditions in a block' do
      get '/app2'
      assert_equal 404, last_response.status
    end

    it 'passes nested routing conditions' do
      header 'X-Cond2', 'true'
      header 'X-Cond3', 'true'
      get '/app3'
      assert_equal 200, last_response.status
    end

    it 'fails nested routing conditions' do
      header 'X-Cond2', 'true'
      get '/app3'
      assert_equal 404, last_response.status
    end
  end

  describe 'as middleware' do
    def app
      Rack::Builder.new do
        use Sinatra::Router do
          mount Apps[0]
          mount Apps[1], condition(1)

          with_conditions(condition(2)) do
            mount Apps[2]
            with_conditions(condition(3)) { mount Apps[3] }
          end
        end

        run ->(_env) { [404, {}, []] }
      end
    end

    it 'routes to an app' do
      get '/app0'
      assert_equal 200, last_response.status
    end

    it 'responds with 404' do
      get '/not-found'
      assert_equal 404, last_response.status
    end

    it 'passes routing conditions' do
      header 'X-Cond1', 'true'
      get '/app1'
      assert_equal 200, last_response.status
    end

    it 'fails routing conditions' do
      get '/app1'
      assert_equal 404, last_response.status
    end

    it 'passes routing conditions in a block' do
      header 'X-Cond2', 'true'
      get '/app2'
      assert_equal 200, last_response.status
    end

    it 'fails routing conditions in a block' do
      get '/app2'
      assert_equal 404, last_response.status
    end

    it 'passes nested routing conditions' do
      header 'X-Cond2', 'true'
      header 'X-Cond3', 'true'
      get '/app3'
      assert_equal 200, last_response.status
    end

    it 'fails nested routing conditions' do
      header 'X-Cond2', 'true'
      get '/app3'
      assert_equal 404, last_response.status
    end

    describe 'with method override' do
      def app
        Rack::Builder.new do
          use Sinatra::Router do
            mount Apps[0]
          end

          run AppWithMethodOverride
        end
      end

      it 'converts the method to get' do
        post '/app0', { _method: 'get' }
        assert_equal 200, last_response.status
      end
    end

    describe 'without method override' do
      def app
        Rack::Builder.new do
          use Sinatra::Router do
            mount Apps[0]
          end

          run App
        end
      end

      it 'does not convert the method to get' do
        post '/app0', { _method: 'get' }
        assert_equal 404, last_response.status
      end
    end
  end
end
