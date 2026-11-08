# frozen_string_literal: true

require 'glib2'
require 'gio2'
require 'open3'
require 'erb'
require 'uri'

# YelpUri resolves an address string (ghelp:, help:, man:, info:, file:,
# xref:, help-list:, a bare path, or anything else) into a document type, a
# canonical URI, a `Gio::File`, a search path, and a page/fragment id pair —
# the data every document backend and YelpView need before they can load a
# page.
#
# Ported from libyelp/yelp-uri.c / .h. Upstream resolves in a worker thread
# (`resolve_start`/`resolve_async`) and signals "resolved" back on the main
# loop so a caller that already holds an unresolved `YelpUri` is never
# blocked; this port's filesystem probing (`File.exist?`, `Gio::File#query_info`,
# one `man -w` subprocess) is fast enough, and this app has no long-lived
# unresolved `YelpUri` sitting around waiting on something else, that
# resolving synchronously on `#resolve!` is the whole porting decision: there
# is one resolve path (upstream's `resolve_sync`), called directly, with no
# thread and no "resolved" signal to wire up. `#resolve!` is therefore both
# upstream's `yelp_uri_resolve` and `yelp_uri_resolve_sync`.
#
# `--editor-mode` (upstream's `index.page.stub` fallback in `resolve_gfile`)
# and the `/proc` guard in `resolve_ghelp_uri` are not carried over; neither
# this port's window chrome nor its command line accepts `--editor-mode` yet
# (see `exe/yelp-rb`), so there is no flag to thread through here.
class YelpUri
  DOCUMENT_TYPES = %i[
    unresolved docbook mallard man info text html xhtml help_list not_found external error
  ].freeze

  MAN_CATEGORIES = %w[
    0p 1 1p 1g 1t 1x 1ssl 1m 2 3 3o 3t 3p 3blt 3nas 3form 3menu 3tiff 3ssl 3readline
    3ncurses 3curses 3f 3pm 3perl 3qt 3x 3X11 4 4x 5 5snmp 5x 5ssl 6 6x 7 7gcc 7x 7ssl 8 8l 9
  ].freeze

  INFO_SUFFIXES = %w[.info .info.gz .info.bz2 .info.lzma .gz .bz2 .lzma].freeze

  DEFAULT_INFO_PATH = '/usr/info:/usr/share/info:/usr/local/info:/usr/local/share/info'

  MAN_NAME_RE = /
    \Aman:((?:[^ \/.()#]|\.(?=[^0-9]))+)
    (\(([0-9A-Za-z]+)\)|\.([0-9A-Za-z]+)|)
    (\#([^\/ ()]+))?
  /x

  attr_reader :document_type, :page_id, :frag_id

  def initialize(arg, base: nil)
    @base = base
    @arg = arg
    @document_type = :unresolved
    @query = {}
  end

  def self.search(base, text)
    new("xref:search=#{ERB::Util.url_encode(text)}", base: base)
  end

  def resolved? = @document_type != :unresolved

  # Upstream's `yelp_uri_resolve`/`yelp_uri_resolve_sync` combined (see the
  # class comment above for why this port has only one resolve path).
  def resolve!
    unless resolved?
      @base&.resolve!
      @tmp_type = :unresolved
      resolve_arg(@arg)
      @document_type = @tmp_type == :unresolved ? :error : @tmp_type
      @full_uri ||= @arg
    end
    self
  end

  def canonical_uri = resolved? ? @full_uri : nil

  def document_uri = resolved? ? (@doc_uri || @full_uri) : nil

  def file = resolved? ? @gfile : nil

  def search_path = resolved? ? @search_path : nil

  def query(key) = @query[key]

  def locate_file_uri(filename)
    if File.absolute_path?(filename)
      File.exist?(filename) ? Gio::File.new_for_path(filename).uri : nil
    else
      (@search_path || []).lazy.map { |dir| File.join(dir, filename) }
                           .find { |path| File.exist?(path) }
                           &.then { |path| Gio::File.new_for_path(path).uri }
    end
  end

  private

    def resolve_arg(arg)
      if arg.start_with?('ghelp:', 'gnome-help:')
        resolve_ghelp_uri(arg)
      elsif arg.start_with?('help:')
        resolve_help_uri(arg)
      elsif arg.start_with?('help-list:')
        resolve_help_list_uri(arg)
      elsif arg.start_with?('file:')
        resolve_file_uri(arg)
      elsif arg.start_with?('man:')
        resolve_man_uri(arg)
      elsif arg.start_with?('info:')
        resolve_info_uri(arg)
      elsif arg.start_with?('xref:')
        resolve_xref_uri(arg)
      elsif arg.include?(':')
        @tmp_type = :external
      else
        resolve_file_path(arg)
      end
    end

    # Splits `rest` (the part of a ghelp:/help: address after the scheme's
    # colon) into [document, slash_part, query_part, hash_part], exactly as
    # upstream's character-scanning loop in resolve_ghelp_uri/resolve_help_uri
    # does: the first '#' found wins as the fragment; '?' only counts as a
    # query if it occurs before that '#'; '/' only counts as the page slash
    # if it occurs before both.
    def split_document_address(rest)
      hash_idx = rest.index('#')
      query_idx = rest.index('?')
      query_idx = nil if query_idx && hash_idx && query_idx > hash_idx
      slash_idx = rest.index('/')
      slash_idx = nil if slash_idx && query_idx && slash_idx > query_idx
      slash_idx = nil if slash_idx && hash_idx && slash_idx > hash_idx

      doc_end = slash_idx || query_idx || hash_idx || rest.length
      slash_end = query_idx || hash_idx || rest.length
      query_end = hash_idx || rest.length

      [
        rest[0...doc_end],
        slash_idx ? rest[(slash_idx + 1)...slash_end] : nil,
        query_idx ? rest[(query_idx + 1)...query_end] : nil,
        hash_idx ? rest[(hash_idx + 1)..] : nil,
      ]
    end

    # Ported from resolve_data_dirs: scans every (XDG data dir) x (language)
    # pair for a help directory, collecting every directory that exists into
    # the eventual search path while keeping only the *first* match's
    # document type and canonical file.
    def resolve_data_dirs(subdir, docid, pageid, langfirst:)
      datadirs = [GLib.user_data_dir, *GLib.system_data_dirs]
      langs = GLib.language_names
      search_path = []
      canonical_file = nil

      datadirs.each do |datadir|
        langs.each do |lang|
          helpdir = langfirst ? File.join(datadir, subdir, lang, docid) : File.join(datadir, subdir, docid, lang)
          if File.directory?(helpdir)
            search_path << helpdir
            if @tmp_type == :unresolved
              canonical_file = data_dir_match(helpdir, pageid, langfirst: langfirst)
              @tmp_type = canonical_file ? canonical_file[1] : :unresolved
              canonical_file &&= canonical_file[0]
            end
          end
        end
      end

      if @tmp_type == :unresolved
        @tmp_type = :not_found
      else
        @gfile = Gio::File.new_for_path(canonical_file)
        @search_path = search_path
      end
    end

    def data_dir_match(helpdir, pageid, langfirst:)
      mallard = File.join(helpdir, 'index.page')
      if File.file?(mallard)
        [helpdir, :mallard]
      elsif langfirst && File.file?(File.join(helpdir, 'index.docbook'))
        [File.join(helpdir, 'index.docbook'), :docbook]
      elsif !langfirst && File.file?(File.join(helpdir, "#{pageid}.xml"))
        [File.join(helpdir, "#{pageid}.xml"), :docbook]
      elsif File.file?(File.join(helpdir, "#{pageid}.html"))
        [File.join(helpdir, "#{pageid}.html"), :html]
      elsif File.file?(File.join(helpdir, "#{pageid}.xhtml"))
        [File.join(helpdir, "#{pageid}.xhtml"), :xhtml]
      end
    end

    def build_ghelp_full_uri
      @full_uri = "#{@doc_uri}#{@tmp_type == :mallard ? '/' : ''}" \
                  "#{@page_id ? "?#{@page_id}" : ''}#{@frag_id ? "##{@frag_id}" : ''}"
    end

    # ghelp:/path/to/file or ghelp:document[/page][?query][#frag]
    def resolve_ghelp_uri(arg)
      colon = arg.index(':')
      if colon.nil?
        @tmp_type = :error
      else
        document, slash, query, hash = split_document_address(arg[(colon + 1)..])
        resolve_ghelp_document(arg, document, slash, query, hash)
      end
    end

    def resolve_ghelp_document(arg, document, slash, query, hash)
      if arg[arg.index(':') + 1] == '/'
        resolve_ghelp_path(File.join('/', slash.to_s), query, hash)
      else
        resolve_data_dirs('gnome/help', document, slash || document, langfirst: false)
        assign_ghelp_page_and_frag(query, hash)
        @doc_uri = "ghelp:#{document}#{slash ? "/#{slash}" : ''}"
        build_ghelp_full_uri
      end
    end

    def resolve_ghelp_path(path, query, hash)
      if File.exist?(path)
        @gfile = Gio::File.new_for_path(path)
        resolve_gfile(query, hash)
      else
        @gfile = Gio::File.new_for_path(File.dirname(path))
        resolve_gfile(File.basename(path), hash)
      end
    end

    def assign_ghelp_page_and_frag(query, hash)
      if query && hash
        @page_id = query
        @frag_id = hash
      elsif query
        @page_id = query
        @frag_id = query unless @tmp_type == :mallard
      elsif hash
        @page_id = hash
        @frag_id = hash
      end
      @frag_id = nil if @frag_id&.start_with?('search=')
    end

    # help:document[/page][?query][#frag]
    def resolve_help_uri(arg)
      colon = arg.index(':')
      if colon.nil?
        @tmp_type = :error
      else
        document, slash, query, hash = split_document_address(arg[(colon + 1)..])
        resolve_help_document(document, slash, query, hash)
      end
    end

    def resolve_help_document(document, slash, query, hash)
      if query
        query.split('&').each do |pair|
          key, _, value = pair.partition('=')
          @query[URI.decode_www_form_component(key)] = URI.decode_www_form_component(value) unless value.empty?
        end
      end

      @page_id = slash || 'index'
      resolve_data_dirs('help', document, @page_id, langfirst: true)
      @frag_id = hash
      @frag_id = nil if @frag_id&.start_with?('search=')
      @doc_uri = "help:#{document}"
      @full_uri = "#{@doc_uri}#{@page_id ? "/#{@page_id}" : ''}#{query ? "?#{query}" : ''}" \
                  "#{@frag_id ? "##{@frag_id}" : ''}"
    end

    def resolve_help_list_uri(arg)
      @doc_uri = 'help-list:'
      @full_uri = arg
      @page_id = 'index'
      @tmp_type = :help_list
    end

    # man:/path/to/file, man:name(section), man:name.section, man:name
    def resolve_man_uri(arg)
      if arg.start_with?('man:search=')
        @tmp_type = :man
        @doc_uri = 'man'
        @full_uri = arg
        @page_id = arg[4..]
      else
        match = MAN_NAME_RE.match(arg)
        if match
          resolve_man_name(match[1], match[3] || match[4], match[6])
        else
          resolve_man_path(arg[4..])
        end
      end
    end

    def resolve_man_path(path)
      @tmp_type = :man
      @gfile = Gio::File.new_for_path(path)
      name = @gfile.basename
      %w[gz bz2 lzma].each do |suffix|
        if man_path?(name, suffix)
          name = name[0...-(suffix.length + 1)]
          break
        end
      end
      build_man_uris(name, nil)
    end

    def resolve_man_name(name, section, hash)
      section = nil if section&.empty?
      path = find_man_path(name, section)
      if path.nil?
        @tmp_type = :not_found
      else
        @tmp_type = :man
        @gfile = Gio::File.new_for_path(path)
        build_man_uris(name, section)
        resolve_page_and_frag(hash) if hash && !hash.empty?
      end
    end

    def build_man_uris(name, section)
      @doc_uri = 'man:'
      @full_uri = "man:#{name}#{section ? ".#{section}" : ''}"
      @page_id = "#{name}#{section ? ".#{section}" : ''}"
    end

    # Shells out to `man -w`, exactly as upstream's find_man_path does.
    def find_man_path(name, section)
      argv = section ? ['man', '-w', section, name] : ['man', '-w', name]
      stdout, _stderr, status = Open3.capture3(*argv)
      status.success? ? stdout.split("\n").first : nil
    rescue Errno::ENOENT
      nil
    end

    def man_path?(path, encoding)
      MAN_CATEGORIES.any? { |cat| path.end_with?(encoding && !encoding.empty? ? "#{cat}.#{encoding}" : cat) }
    end

    def build_info_uris(name, section)
      @doc_uri = "info:#{name}"
      @full_uri = "#{@doc_uri}#{section ? "##{section}" : ''}"
      @page_id = section
      @frag_id = section
    end

    # info:/path/to/file, info:name#node, info:name, info:(name)node
    def resolve_info_uri(arg)
      if arg.start_with?('info:/')
        resolve_info_path(arg)
      else
        resolve_info_name(arg)
      end
    end

    def resolve_info_path(arg)
      @tmp_type = :info
      hash = arg.index('#', 5)
      if hash
        @gfile = Gio::File.new_for_path(arg[5...hash])
        section = arg[(hash + 1)..]
      else
        @gfile = Gio::File.new_for_path(arg[5..])
        section = nil
      end
      name = @gfile.basename
      INFO_SUFFIXES.each do |suffix|
        if name.end_with?(suffix)
          name = name[0...-suffix.length]
          break
        end
      end
      build_info_uris(name, section)
    end

    def info_path = ENV.fetch('INFOPATH', '').then { |env|
      if env.empty?
        DEFAULT_INFO_PATH
      elsif env.end_with?(':')
        "#{env}#{DEFAULT_INFO_PATH}"
      else
        env
      end
    }.split(':')

    def resolve_info_name(arg)
      colon = arg.index(':')
      rest = colon ? arg[(colon + 1)..] : arg
      name, section = parse_info_name(rest)
      fullpath = info_path.each_with_object(nil) do |dir, _|
        break nil unless File.directory?(dir)
        found = INFO_SUFFIXES.map { |suffix| File.join(dir, "#{name}#{suffix}") }.find { |p| File.file?(p) }
        break found if found
      end
      resolve_info_name_result(arg, name, section, fullpath)
    end

    def parse_info_name(rest)
      if rest.start_with?('(')
        rbrace = rest.index(')')
        rbrace ? [rest[1...rbrace], rest[(rbrace + 1)..]] : [rest[1..], nil]
      else
        hash = rest.index('#')
        hash ? [rest[0...hash], rest[(hash + 1)..]] : [rest, nil]
      end
    end

    def resolve_info_name_result(arg, name, section, fullpath)
      if fullpath
        @tmp_type = :info
        @gfile = Gio::File.new_for_path(fullpath)
        build_info_uris(name, section)
      else
        saved_arg = @arg
        @arg = "man:#{name}"
        resolve_man_uri(@arg)
        @arg = saved_arg
        @tmp_type = :not_found if @tmp_type != :man
      end
    end

    def resolve_xref_uri(arg)
      if @base.nil?
        @tmp_type = :error
      else
        resolve_xref_against_base(arg)
      end
    end

    def resolve_xref_against_base(arg)
      rest = arg[5..]
      case @base.document_type
      when :docbook, :mallard, :info
        resolve_xref_document(rest)
      when :man
        resolve_man_uri("man:#{rest}")
      when :text, :html, :xhtml
        resolve_file_path(rest)
      end
    end

    def resolve_xref_document(arg)
      @tmp_type = @base.document_type
      @gfile = @base.file
      @search_path = @base.search_path
      @doc_uri = @base.document_uri

      if arg.start_with?('#')
        @page_id = @base.page_id
        @frag_id = arg[1..]
      else
        hash = arg.index('#')
        @page_id = hash ? arg[0...hash] : arg
        @frag_id = hash ? arg[(hash + 1)..] : nil
      end

      if @page_id&.empty?
        @page_id = @doc_uri.start_with?('help:') ? 'index' : nil
      end

      @page_id = URI.decode_www_form_component(@page_id) if @page_id && @doc_uri.start_with?('info:')

      build_xref_full_uri
    end

    def build_xref_full_uri
      if @doc_uri.start_with?('ghelp:')
        build_ghelp_full_uri
      elsif @doc_uri.start_with?('help:')
        @full_uri = "#{@doc_uri}#{@page_id ? "/#{@page_id}" : ''}#{@frag_id ? "##{@frag_id}" : ''}"
      elsif @doc_uri.start_with?('file:', 'info:')
        @full_uri = "#{@doc_uri}#{@page_id || @frag_id ? '#' : ''}#{@page_id}#{@frag_id ? "##{@frag_id}" : ''}"
      else
        @full_uri = "#{@doc_uri}#{@page_id ? "##{@page_id}" : ''}"
      end
    end

    def resolve_page_and_frag(arg)
      unless arg.nil? || arg.empty?
        hash = arg.index('#')
        @page_id = hash ? arg[0...hash] : arg
        @frag_id = hash ? arg[(hash + 1)..] : arg
      end
    end

    def resolve_file_uri(arg)
      hash = arg.index('#')
      uristr = hash ? arg[0...hash] : arg
      @gfile = Gio::File.new_for_uri(uristr)
      resolve_gfile(nil, hash ? arg[(hash + 1)..] : nil)
    end

    def resolve_file_path(arg)
      path = arg.start_with?('xref:') ? arg[5..] : arg
      hash = path.index('#')
      path, hash = hash ? [path[0...hash], path[(hash + 1)..]] : [path, nil]

      if path.start_with?('/')
        @gfile = Gio::File.new_for_path(path)
      elsif @base&.file
        @gfile = resolve_relative_to_base(path)
      else
        @gfile = Gio::File.new_for_path(File.join(Dir.pwd, path))
      end

      resolve_gfile(nil, hash)
    end

    def resolve_relative_to_base(path)
      base_file = @base.file
      if base_file.query_info('standard::type', Gio::FileQueryInfoFlags::NONE).file_type == Gio::FileType::REGULAR
        base_file.parent.resolve_relative_path(path)
      else
        base_file.resolve_relative_path(path)
      end
    end

    # Ported from resolve_gfile: sniffs a GFile's content type to pick a
    # document type, the same scheme-detection upstream's YelpView relies on
    # once a backend exists to hand the file to.
    def resolve_gfile(query, hash)
      info = @gfile.query_info('standard::type,standard::fast-content-type', Gio::FileQueryInfoFlags::NONE)
      @search_path ||= [gfile_default_search_dir(info)]
      resolve_gfile_type(info, query, hash) if @tmp_type == :unresolved
      @doc_uri ||= @gfile.uri
      @full_uri ||= "#{@doc_uri}#{@page_id || @frag_id ? '#' : ''}#{@page_id}#{@frag_id ? "##{@frag_id}" : ''}"
    rescue Gio::IOError::NotFound
      @tmp_type = :not_found
    rescue GLib::Error
      @tmp_type = :error
    end

    def gfile_default_search_dir(info)
      info.file_type == Gio::FileType::DIRECTORY ? @gfile.path : @gfile.parent.path
    end

    def resolve_gfile_type(info, query, hash)
      @tmp_type = :external
      if info.file_type == Gio::FileType::DIRECTORY
        resolve_gfile_directory(query, hash)
      else
        resolve_gfile_regular(info, query, hash)
      end
    end

    def resolve_gfile_directory(query, hash)
      index_page = @gfile.get_child('index.page')
      if index_page.query_exists
        @tmp_type = :mallard
        @page_id ||= query
        @frag_id ||= hash
        @doc_uri = "ghelp:#{@gfile.path}"
        build_ghelp_full_uri
      end
    end

    def resolve_gfile_regular(info, query, hash)
      basename = @gfile.basename
      mime_type = info.get_attribute_string('standard::fast-content-type')
      if basename.end_with?('.page')
        resolve_gfile_mallard_page(basename, hash)
      elsif %w[text/xml application/docbook+xml application/xml].include?(mime_type) || basename.end_with?('.docbook')
        resolve_gfile_docbook(query: query, hash: hash)
      else
        resolve_gfile_by_mime_type(mime_type, basename, hash)
      end
    end

    def resolve_gfile_mallard_page(basename, hash)
      @tmp_type = :mallard
      parent = @gfile.parent
      @gfile = parent
      @page_id ||= "/#{basename}"
      @frag_id ||= hash
      @doc_uri = "ghelp:#{parent.path}"
      build_ghelp_full_uri
    end

    def resolve_gfile_docbook(query:, hash:)
      @tmp_type = :docbook
      @page_id ||= query
      @frag_id ||= hash
      @doc_uri = "ghelp:#{@gfile.path}"
      build_ghelp_full_uri
    end

    def resolve_gfile_by_mime_type(mime_type, basename, hash)
      if %w[text/html application/xhtml+xml].include?(mime_type)
        resolve_gfile_html(mime_type, basename, hash)
      elsif %w[application/x-gzip application/gzip].include?(mime_type)
        resolve_gfile_compressed(basename, 'gz')
      elsif mime_type == 'application/x-bzip'
        resolve_gfile_compressed(basename, 'bz2')
      elsif mime_type == 'application/x-lzma'
        resolve_gfile_compressed(basename, 'lzma')
      elsif mime_type == 'application/octet-stream'
        resolve_gfile_plain(basename, hash: nil)
      elsif mime_type == 'text/plain'
        resolve_gfile_plain(basename, hash: hash)
      elsif mime_type == 'text/x-readme'
        @tmp_type = :text
      end
    end

    def resolve_gfile_html(mime_type, basename, hash)
      @doc_uri = @gfile.parent.uri
      @tmp_type = mime_type == 'text/html' ? :html : :xhtml
      @page_id ||= basename
      @frag_id ||= hash
      @full_uri ||= "#{@gfile.uri}#{@frag_id ? "##{@frag_id}" : ''}"
    end

    def resolve_gfile_compressed(basename, encoding)
      if basename.end_with?(".info.#{encoding}")
        @tmp_type = :info
        build_info_uris(basename[0...-".info.#{encoding}".length], nil)
      elsif man_path?(basename, encoding)
        @tmp_type = :man
        build_man_uris(basename[0...-(encoding.length + 1)], nil)
      end
    end

    def resolve_gfile_plain(basename, hash:)
      if basename.end_with?('.info')
        @tmp_type = :info
        build_info_uris(basename[0...-'.info'.length], hash)
      elsif man_path?(basename, nil)
        @tmp_type = :man
        build_man_uris(basename, nil)
      else
        @tmp_type = :text
        @frag_id ||= hash
      end
    end
end
