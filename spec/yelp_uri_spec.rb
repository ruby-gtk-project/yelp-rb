# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../lib/yelp_uri'

# Ported from tests/test-uri.c and the ten fixtures under tests/uri/*.test.
# Upstream's fixtures assert against documents the test runner expects
# already installed on the host (/usr/share/gnome/help/user-guide, a
# system `flac` man page, …), which this sandbox has none of. Each example
# below rebuilds the same directory shape — a ghelp docbook/mallard tree
# under a throwaway XDG data dir, a man page under a throwaway MANPATH, an
# info file under a throwaway INFOPATH — so the *resolution logic*
# (upstream's spec here) is exercised the same way, without depending on
# what happens to be installed on the machine running the suite.
RSpec.describe YelpUri do
  around do |example|
    Dir.mktmpdir('yelp-uri-spec') { |dir| @fixture = dir; example.run }
  end

  def resolved(arg, base: nil)
    described_class.new(arg, base: base).tap(&:resolve!)
  end

  describe 'ghelp: and help: documents' do
    before do
      FileUtils.mkdir_p(File.join(@fixture, 'share/gnome/help/user-guide/C'))
      File.write(File.join(@fixture, 'share/gnome/help/user-guide/C/user-guide.xml'), '<x/>')
      FileUtils.mkdir_p(File.join(@fixture, 'share/gnome/help/mallard-spec/C'))
      File.write(File.join(@fixture, 'share/gnome/help/mallard-spec/C/index.page'), '<page/>')
      FileUtils.mkdir_p(File.join(@fixture, 'share/help/C/gnome-help'))
      File.write(File.join(@fixture, 'share/help/C/gnome-help/index.page'), '<page/>')
      stub_env('XDG_DATA_DIRS' => "#{File.join(@fixture, 'share')}:#{ENV.fetch('XDG_DATA_DIRS', '')}")
    end

    it 'resolves a docbook document, matching ghelp-docbook-1.test' do
      uri = resolved('ghelp:user-guide')
      expect(uri.document_type).to eq(:docbook)
      expect(uri.document_uri).to eq('ghelp:user-guide')
      expect(uri.canonical_uri).to eq('ghelp:user-guide')
      expect(uri.file.uri).to end_with('/user-guide/C/user-guide.xml')
      expect(uri.search_path).to contain_exactly(File.join(@fixture, 'share/gnome/help/user-guide/C'))
    end

    it 'resolves a docbook xref, matching ghelp-docbook-2.test' do
      base = resolved('ghelp:user-guide')
      uri = resolved('xref:gosnautilus', base: base)
      expect(uri.document_type).to eq(:docbook)
      expect(uri.canonical_uri).to eq('ghelp:user-guide?gosnautilus')
      expect(uri.page_id).to eq('gosnautilus')
    end

    it 'resolves a mallard document, matching ghelp-mallard-1.test' do
      uri = resolved('ghelp:mallard-spec')
      expect(uri.document_type).to eq(:mallard)
      expect(uri.document_uri).to eq('ghelp:mallard-spec')
      expect(uri.canonical_uri).to eq('ghelp:mallard-spec/')
    end

    it 'resolves a mallard xref, matching ghelp-mallard-2.test' do
      base = resolved('ghelp:mallard-spec')
      uri = resolved('xref:mal_block#basic', base: base)
      expect(uri.document_type).to eq(:mallard)
      expect(uri.canonical_uri).to eq('ghelp:mallard-spec/?mal_block#basic')
      expect(uri.page_id).to eq('mal_block')
      expect(uri.frag_id).to eq('basic')
    end

    it 'resolves a help: document to the language-first search tree' do
      uri = resolved('help:gnome-help')
      expect(uri.document_type).to eq(:mallard)
      expect(uri.document_uri).to eq('help:gnome-help')
      expect(uri.page_id).to eq('index')
    end
  end

  describe 'bare filesystem paths' do
    before do
      FileUtils.mkdir_p(File.join(@fixture, 'docbook'))
      File.write(File.join(@fixture, 'docbook/user-guide.xml'), '<x/>')
      FileUtils.mkdir_p(File.join(@fixture, 'mallard'))
      File.write(File.join(@fixture, 'mallard/index.page'), '<page/>')
    end

    it 'resolves an absolute docbook path, matching path-docbook-1.test' do
      uri = resolved(File.join(@fixture, 'docbook/user-guide.xml'))
      expect(uri.document_type).to eq(:docbook)
      expect(uri.document_uri).to eq("ghelp:#{File.join(@fixture, 'docbook/user-guide.xml')}")
      expect(uri.search_path).to contain_exactly(File.join(@fixture, 'docbook'))
    end

    it 'keeps the fragment on the canonical uri, matching path-docbook-2.test' do
      uri = resolved("#{File.join(@fixture, 'docbook/user-guide.xml')}#gosnautilus")
      expect(uri.frag_id).to eq('gosnautilus')
      expect(uri.canonical_uri).to end_with('#gosnautilus')
    end

    it 'resolves an absolute mallard directory, matching path-mallard-1.test' do
      uri = resolved(File.join(@fixture, 'mallard/'))
      expect(uri.document_type).to eq(:mallard)
      expect(uri.document_uri).to eq("ghelp:#{File.join(@fixture, 'mallard')}")
    end

    it 'keeps the fragment, matching path-mallard-2.test' do
      uri = resolved("#{File.join(@fixture, 'mallard')}#mal_block")
      expect(uri.page_id).to eq('mal_block')
    end
  end

  describe 'man: and info: documents' do
    it 'resolves a man page given as a bare file path' do
      FileUtils.mkdir_p(File.join(@fixture, 'man1'))
      File.write(File.join(@fixture, 'man1/foo.1'), '.TH foo 1')
      uri = resolved("man:#{File.join(@fixture, 'man1/foo.1')}")
      expect(uri.document_type).to eq(:man)
      expect(uri.canonical_uri).to eq('man:foo.1')
      expect(uri.page_id).to eq('foo.1')
    end

    it 'resolves an absolute info: path, matching the test-uri.c info case' do
      FileUtils.mkdir_p(File.join(@fixture, 'info'))
      File.write(File.join(@fixture, 'info/bar.info'), 'Fake info')
      uri = resolved("info:/#{File.join(@fixture, 'info/bar.info')}")
      expect(uri.document_type).to eq(:info)
      expect(uri.document_uri).to eq('info:bar')
    end

    it 'resolves info:name by scanning INFOPATH' do
      FileUtils.mkdir_p(File.join(@fixture, 'info'))
      File.write(File.join(@fixture, 'info/bar.info'), 'Fake info')
      stub_env('INFOPATH' => File.join(@fixture, 'info'))
      uri = resolved('info:bar')
      expect(uri.document_type).to eq(:info)
      expect(uri.file.path).to eq(File.join(@fixture, 'info/bar.info'))
    end

    it 'falls back to not_found when a man page cannot be found at all' do
      stub_env('PATH' => '/nonexistent')
      uri = resolved('man:totally-nonexistent-command')
      expect(uri.document_type).to eq(:not_found)
    end
  end

  describe 'other schemes' do
    it 'resolves help-list: to the help_list type' do
      uri = resolved('help-list:')
      expect(uri.document_type).to eq(:help_list)
      expect(uri.page_id).to eq('index')
    end

    it 'treats an unknown scheme as external' do
      uri = resolved('https://example.com/')
      expect(uri.document_type).to eq(:external)
    end

    it 'reports not_found for a ghelp: document that does not exist' do
      stub_env('XDG_DATA_DIRS' => @fixture)
      uri = resolved('ghelp:totally-nonexistent-document')
      expect(uri.document_type).to eq(:not_found)
    end

    it 'is unresolved before #resolve! and resolved after' do
      uri = described_class.new('help-list:')
      expect(uri.resolved?).to be(false)
      uri.resolve!
      expect(uri.resolved?).to be(true)
    end
  end
end
