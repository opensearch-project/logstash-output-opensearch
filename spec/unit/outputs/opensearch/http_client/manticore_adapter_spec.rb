# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/opensearch/http_client"
require 'cabin'

describe LogStash::Outputs::OpenSearch::HttpClient::ManticoreAdapter do
  let(:logger) { Cabin::Channel.get }
  let(:options) { {} }

  subject { described_class.new(logger, options) }

  it "should raise an exception if requests are issued after close" do
    subject.close
    expect { subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, '/') }.to raise_error(::Manticore::ClientStoppedException)
  end

  it "should implement host unreachable exceptions" do
    expect(subject.host_unreachable_exceptions).to be_a(Array)
  end

  describe "auth" do
    let(:user) { "myuser" }
    let(:password) { "mypassword" }
    let(:noauth_uri) { clone = uri.clone; clone.user=nil; clone.password=nil; clone }
    let(:uri) { ::LogStash::Util::SafeURI.new("http://#{user}:#{password}@localhost:9200") }

    it "should convert the auth to params" do
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(200)
      
      expected_uri = noauth_uri.clone
      expected_uri.path = "/"

      expect(subject.manticore).to receive(:get).
        with(expected_uri.to_s, {
          :headers => {"content-type" => "application/json"},
          :auth => {
            :user => user,
            :password => password,
            :eager => true
          }
        }).and_return resp
      
      subject.perform_request(uri, :get, "/")
    end
  end

  describe "aws_iam" do
    let(:options) { {
      :auth_type => {
        "type"=>"aws_iam",
        "aws_access_key_id"=>"AAAAAAAAAAAAAAAAAAAA",
        "aws_secret_access_key"=>"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}
    } }
    let(:options_svc) { {
      :auth_type => {
        "type"=>"aws_iam",
        "aws_access_key_id"=>"AAAAAAAAAAAAAAAAAAAA",
        "aws_secret_access_key"=>"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "service_name"=>"svc_test"}
    } }
    subject { described_class.new(logger, options) }
    let(:uri) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }

    let(:expected_uri) {
      expected_uri = uri.clone
      expected_uri.path = "/"
      expected_uri
    }

    let(:resp) {
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(200)
      resp
    }

    context 'with a signer' do
      let(:sign_aws_request) {  }

      it "should validate AWS IAM credentials initialization" do
        expect(subject.aws_iam_auth_initialization(options)).not_to be_nil
        expect(subject.get_service_name).to eq("es")
      end

      it "should validate AWS IAM service_name config" do
        expect(subject.aws_iam_auth_initialization(options_svc)).not_to be_nil
        expect(subject.get_service_name).to eq("svc_test")
      end

      it "should validate signing aws request" do
        allow(subject).to receive(:sign_aws_request).with(any_args).and_return(sign_aws_request)

        expect(subject.manticore).to receive(:get).
          with(expected_uri.to_s, {
            :headers => {"content-type"=> "application/json"}
          }
          ).and_return resp

        expect(subject).to receive(:sign_aws_request)
        subject.perform_request(uri, :get, "/")
      end
    end

    context 'sign_aws_request' do
      it 'handles UTF-8' do
        encoded_body = body = "boîte de réception"
        expect_any_instance_of(Aws::Sigv4::Signer).to receive(:sign_request).with(hash_including({
            body: body,
        })).and_return(
          double(headers: {})
        )
        expect(subject.manticore).to receive(:post).
          with(expected_uri.to_s, {
            :body => encoded_body,
            :headers => {"content-type"=> "application/json"}
          }
        ).and_return resp
        subject.perform_request(uri, :post, "/", { body: encoded_body })
      end

      it 'encodes body before signing to match manticore adapter encoding' do
        body = "boîte de réception"
        encoded_body = body.encode("ISO-8859-1")
        expect_any_instance_of(Aws::Sigv4::Signer).to receive(:sign_request).with(hash_including({
            body: body,
        })).and_return(
          double(headers: {})
        )
        expect(subject.manticore).to receive(:post).
          with(expected_uri.to_s, {
            :body => encoded_body,
            :headers => {"content-type"=> "application/json"}
          }
        ).and_return resp
        subject.perform_request(uri, :post, "/", { body: encoded_body })
      end
    end
  end

  describe "basic_auth" do
    let(:options) { {
      :auth_type => {
        "type"=>"basic",
        "user" => "myuser",
        "password" => "mypassword"}
    } }
    subject { described_class.new(logger, options) }
    let(:user) {options[:auth_type]["user"]}
    let(:password) {options[:auth_type]["password"]}
    let(:noauth_uri) { clone = uri.clone; clone.user=nil; clone.password=nil; clone }
    let(:uri) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }

    it "should validate master credentials with type as 'basic_auth'" do
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(200)

      expected_uri = noauth_uri.clone
      expected_uri.path = "/"

      expect(subject.manticore).to receive(:get).
        with(expected_uri.to_s, {
          :headers => {"content-type" => "application/json"},
          :auth => {
            :user => user,
            :password => password,
            :eager => true
          }
        }).and_return resp

      subject.perform_request(uri, :get, "/")
    end
  end

  describe "bad response codes" do
    let(:uri) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }

    it "should raise a bad response code error" do
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(500)
      allow(resp).to receive(:body).and_return("a body")

      expect(subject.manticore).to receive(:get).
        with(uri.to_s + "/", anything).
        and_return(resp)

      uri_with_path = uri.clone
      uri_with_path.path = "/"

      expect(::LogStash::Outputs::OpenSearch::HttpClient::Pool::BadResponseCodeError).to receive(:new).
        with(resp.code, uri_with_path, nil, resp.body).and_call_original

      expect do
        subject.perform_request(uri, :get, "/")
      end.to raise_error(::LogStash::Outputs::OpenSearch::HttpClient::Pool::BadResponseCodeError)
    end
  end

  describe "format_url" do
    let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/") }
    let(:path) { "_bulk" }
    subject { described_class.new(double("logger"), {}) }

    it "should add the path argument to the uri's path" do
      expect(subject.format_url(url, path).path).to eq("/path/_bulk")
    end

    context "when uri contains query parameters" do
      let(:query_params) { "query=value&key=value2" }
      let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/?#{query_params}") }
      let(:formatted) { subject.format_url(url, path)}

      it "should retain query_params after format" do
        expect(formatted.query).to eq(query_params)
      end
      
      context "and the path contains query parameters" do
        let(:path) { "/special_path?specialParam=123" }
        
        it "should join the query correctly" do
          expect(formatted.query).to eq(query_params + "&specialParam=123")
        end
      end
    end
    
    context "when the path contains query parameters" do
      let(:path) { "/special_bulk?pathParam=1"}
      let(:formatted) { subject.format_url(url, path) }
      
      it "should add the path correctly" do
        expect(formatted.path).to eq("#{url.path}special_bulk")
        expect(subject.remove_double_escaping(formatted.path)).to eq("#{url.path}special_bulk")
      end 
      
      it "should add the query parameters correctly" do
        expect(formatted.query).to eq("pathParam=1")
      end
    end

    context "when uri contains credentials" do
      let(:url) { ::LogStash::Util::SafeURI.new("http://myuser:mypass@localhost:9200") }
      let(:formatted) { subject.format_url(url, path) }

      it "should remove credentials after format" do
        expect(formatted.userinfo).to be_nil
      end
    end

    context 'when uri contains date math' do
      let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }
      let(:path) { CGI.escape("<logstash-{now/d}-0001>") }
      let(:formatted) { subject.format_url(url, path) }

      it 'should escape the uri correctly' do
        expect(subject.remove_double_escaping(formatted.path)).to eq("/%3Clogstash-%7Bnow%2Fd%7D-0001%3E")
      end
    end

    context 'when uri does not contain date math' do
      let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }
      let(:path) { CGI.escape("logstash-0001") }
      let(:formatted) { subject.format_url(url, path) }

      it 'should escape the uri correctly' do
        expect(subject.remove_double_escaping(formatted.path)).to eq("/logstash-0001")
      end
    end
  end

  describe "integration specs", :integration => true do
    it "should perform correct tests without error" do
      resp = subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, "/")
      expect(resp.code).to eql(200)
    end
  end
end
