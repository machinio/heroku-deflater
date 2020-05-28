require 'spec_helper'

describe HerokuDeflater::ServeZippedAssets do
  shared_examples_for 'ServeZippedAssets' do
    %w(assets packs).each do |path|
      it 'does nothing for clients which do not want gzip' do
        status, headers, body = process("/#{path}/spec.js", nil)
        expect(status).to eq(404)
      end

      it 'handles the pre-gzipped assets' do
        status, headers, body = process("/#{path}/spec.js")
        expect(status).to eq(200)
      end

      it 'has correct content type' do
        status, headers, body = process("/#{path}/spec.js")
        expect(headers['Content-Type']).to eq('application/javascript')
      end

      it 'has correct content encoding' do
        status, headers, body = process("/#{path}/spec.js")
        expect(headers['Content-Encoding']).to eq('gzip')
      end

      it 'has correct content length' do
        status, headers, body = process("/#{path}/spec.js")
        expect(headers['Content-Length']).to eq('86')
      end

      it 'has correct cache control' do
        status, headers, body = process("/#{path}/spec.js")
        expect(headers['Cache-Control']).to eq('public, max-age=86400')
      end

      it 'does not serve non-gzipped assets' do
        status, headers, body = process("/#{path}/spec2.js")
        expect(status).to eq(404)
      end

      it 'does not serve anything from non-asset directories' do
        status, headers, body = process("/non-#{path}/spec.js")
        expect(status).to eq(404)
      end
    end
  end

  describe 'Rais 4.x' do
    let(:app) { Rails4App.new }

    before do
      allow(HerokuDeflater).to receive(:rails_version_5?) { false }
    end

    # FIXME: It will work only with gemfiles
    # it_behaves_like 'ServeZippedAssets'
  end

  describe 'Rais 5.x' do
    let(:app) { Rails5App.new }

    before do
      allow(HerokuDeflater).to receive(:rails_version_5?) { true }
    end

    it_behaves_like 'ServeZippedAssets'
  end

  def process(path, accept_encoding = 'compress, gzip, deflate')
    env = Rack::MockRequest.env_for(path)
    env['HTTP_ACCEPT_ENCODING'] = accept_encoding
    middleware.call(env)
  end

  def middleware
    @middleware ||= begin
      root_path = File.expand_path('../fixtures', __FILE__)
      cache_control_manager = HerokuDeflater::CacheControlManager.new(app)
      mock = lambda { |env| [404, {'X-Cascade' => 'pass'}, []] }
      described_class.new(mock, root_path, ['/assets', '/packs'], cache_control_manager)
    end
  end
end
