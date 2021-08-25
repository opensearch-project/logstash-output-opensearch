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

describe LogStash::Outputs::OpenSearch::HttpClient::Pool do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::OpenSearch::HttpClient::ManticoreAdapter.new(logger) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 2, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests
  let(:node_versions) { [ "7.0.0" ] }
  let(:get_distribution) { "opensearch" }

  subject { described_class.new(logger, adapter, initial_urls, options) }

  let(:manticore_double) { double("manticore a") }
  before(:each) do
    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:close)

    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)

    allow(subject).to receive(:get_version).with(any_args).and_return(*node_versions)
    allow(subject.distribution_checker).to receive(:get_distribution).and_return(get_distribution)
  end

  after do
    subject.close
  end

  describe "initialization" do
    it "should be successful" do
      expect { subject }.not_to raise_error
      subject.start
    end
  end

  describe "the resurrectionist" do
    before(:each) { subject.start }
    it "should start the resurrectionist when created" do
      expect(subject.resurrectionist_alive?).to eql(true)
    end

    it "should attempt to resurrect connections after the ressurrect delay" do
      expect(subject).to receive(:healthcheck!).once
      sleep(subject.resurrect_delay + 1)
    end

    describe "healthcheck url handling" do
      let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }

      context "and not setting healthcheck_path" do
        it "performs the healthcheck to the root" do
          expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
            expect(method).to eq(:head)
            expect(url.path).to be_empty
            expect(req_path).to eq("/")
          end
          subject.healthcheck!
        end
      end

      context "and setting healthcheck_path" do
        let(:healthcheck_path) { "/my/health" }
        let(:options) { super().merge(:healthcheck_path => healthcheck_path) }
        it "performs the healthcheck to the healthcheck_path" do
          expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
            expect(method).to eq(:head)
            expect(url.path).to be_empty
            expect(req_path).to eq(healthcheck_path)
          end
          subject.healthcheck!
        end
      end
    end
  end

  describe 'resolving the address from OpenSearch node info' do
    let(:host) { "unit-test-node"}
    let(:ip_address) { "192.168.1.0"}
    let(:port) { 9200 }

    context 'with host and ip address' do
      let(:publish_address) { "#{host}/#{ip_address}:#{port}"}
      it 'should correctly extract the host' do
        expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{host}:#{port}"))
      end
    end
    context 'with ip address' do
      let(:publish_address) { "#{ip_address}:#{port}"}
      it 'should correctly extract the ip address' do
        expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{ip_address}:#{port}"))
      end
    end
  end

  describe "the sniffer" do
    before(:each) { subject.start }
    it "should not start the sniffer by default" do
      expect(subject.sniffer_alive?).to eql(nil)
    end

    context "when enabled" do
      let(:options) { super().merge(:sniffing => true)}

      it "should start the sniffer" do
        expect(subject.sniffer_alive?).to eql(true)
      end
    end
  end

  describe "closing" do
    before do
      subject.start
      # Simulate a single in use connection on the first check of this
      allow(adapter).to receive(:close).and_call_original
      allow(subject).to receive(:wait_for_in_use_connections).and_call_original
      allow(subject).to receive(:in_use_connections).and_return([subject.empty_url_meta()],[])
      allow(subject).to receive(:start)
      subject.close
    end

    it "should close the adapter" do
      expect(adapter).to have_received(:close)
    end

    it "should stop the resurrectionist" do
      expect(subject.resurrectionist_alive?).to eql(false)
    end

    it "should stop the sniffer" do
      # If no sniffer (the default) returns nil
      expect(subject.sniffer_alive?).to be_falsey
    end

    it "should wait for in use connections to terminate" do
      expect(subject).to have_received(:wait_for_in_use_connections).once
      expect(subject).to have_received(:in_use_connections).twice
    end
  end

  describe "connection management" do
    before(:each) { subject.start }
    context "with only one URL in the list" do
      it "should use the only URL in 'with_connection'" do
        subject.with_connection do |c|
          expect(c).to eq(initial_urls.first)
        end
      end
    end

    context "with multiple URLs in the list" do
      before :each do
        allow(adapter).to receive(:perform_request).with(anything, :head, subject.healthcheck_path, {}, nil)
      end
      let(:initial_urls) { [ ::LogStash::Util::SafeURI.new("http://localhost:9200"), ::LogStash::Util::SafeURI.new("http://localhost:9201"), ::LogStash::Util::SafeURI.new("http://localhost:9202") ] }

      it "should minimize the number of connections to a single URL" do
        connected_urls = []

        # If we make 2x the number requests as we have URLs we should
        # connect to each URL exactly 2 times
        (initial_urls.size*2).times do
          u, meta = subject.get_connection
          connected_urls << u
        end

        connected_urls.each {|u| subject.return_connection(u) }
        initial_urls.each do |url|
          conn_count = connected_urls.select {|u| u == url}.size
          expect(conn_count).to eql(2)
        end
      end

      it "should correctly resurrect the dead" do
        u,m = subject.get_connection

        # The resurrectionist will call this to check on the backend
        response = double("response")
        expect(adapter).to receive(:perform_request).with(u, :head, subject.healthcheck_path, {}, nil).and_return(response)

        subject.return_connection(u)
        subject.mark_dead(u, Exception.new)

        expect(subject.url_meta(u)[:state]).to eql(:dead)
        sleep subject.resurrect_delay + 1
        expect(subject.url_meta(u)[:state]).to eql(:alive)
      end
    end
  end

  describe "version tracking" do
    let(:initial_urls) { [
      ::LogStash::Util::SafeURI.new("http://somehost:9200"),
      ::LogStash::Util::SafeURI.new("http://otherhost:9201")
    ] }

    before(:each) do
      allow(subject).to receive(:perform_request_to_url).and_return(nil)
      subject.start
    end

    it "picks the largest major version" do
      expect(subject.maximum_seen_major_version).to eq(7)
    end

    context "if there are nodes with multiple major versions" do
      let(:node_versions) { [ "0.0.0", "7.0.0" ] }
      it "picks the largest major version" do
        expect(subject.maximum_seen_major_version).to eq(7)
      end
    end
  end
  describe "distribution checking" do
    before(:each) do
      allow(subject).to receive(:health_check_request)
    end

    let(:options) do
      super().merge(:distribution_checker => distribution_checker)
    end

    context 'when DistributionChecker#is_supported? returns false' do
      let(:distribution_checker) { double('DistributionChecker', :is_supported? => false) }

      it 'does not mark the URL as active' do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(0)
      end
    end

    context 'when DistributionChecker#is_supported? returns true' do
      let(:distribution_checker) { double('DistributionChecker', :is_supported? => true) }

      it 'marks the URL as active' do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(1)
      end
    end
  end
  describe 'distribution checking with cluster output' do
    let(:options) do
      super().merge(:distribution_checker => LogStash::Outputs::OpenSearch::DistributionChecker.new(logger))
    end

    before(:each) do
      allow(subject).to receive(:health_check_request)
    end

    context 'when using opensearch' do

      context "cluster doesn't return a valid distribution" do
        let(:get_distribution) { nil }
        context "major version is not 7" do
          let(:node_versions) { [ "6.0.0" ] }

          it 'marks the url as dead' do
            subject.update_initial_urls
            expect(subject.alive_urls_count).to eq(0)
          end

          it 'logs message' do
            expect(subject.distribution_checker).to receive(:log_not_supported).once.and_call_original
            subject.update_initial_urls
          end
        end
        context "major version is  7" do
          let(:node_versions) { [ "7.10.2" ] }

          it "marks the url as active" do
            subject.update_initial_urls
            expect(subject.alive_urls_count).to eq(1)
          end

          it 'does not log message' do
            expect(subject.distribution_checker).to_not receive(:log_not_supported)
            subject.update_initial_urls
          end

        end
      end
      context 'cluster returns valid distribution' do
        let(:get_distribution) { 'opensearch' }

        it "marks the url as active" do
          subject.update_initial_urls
          expect(subject.alive_urls_count).to eq(1)
        end

        it 'does not log message' do
          expect(subject.distribution_checker).to_not receive(:log_not_supported)
          subject.update_initial_urls
        end
      end
    end
  end
end
