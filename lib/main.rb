# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'bookmark_row'
require_relative 'settings'
require_relative 'window'

# Application is the whole process: one Gtk::Application, the app-scoped
# actions and accelerators every window shares, and the registry of open
# windows.
#
# Ported from upstream's src/yelp-application.c / .h. Upstream's private
# struct additionally tracks `windows_by_document` (a GHashTable keyed by
# document URI, so opening the same help document twice raises the existing
# window instead of opening a second one) and a `docsettings` cache of
# per-document GSettings objects. I have not ported either: raising an
# existing window needs a document URI to key on, which `lib/yelp_uri.rb`
# (ported this round) can now resolve, but nothing yet calls it from here —
# that wiring, and the per-document `GKeyfileSettingsBackend` cache
# (gio2 has no `g_settings_new_full`/`with_path` binding; see `doc_settings`
# below), are owed work, not done work. This port's registry is the plain
# list `Gtk::Application` already keeps (`windows`) rather than a
# hand-rolled duplicate.
#
# The `-e, --editor-mode` command-line switch from yelp_application_cmdline
# lives in exe/yelp-rb, which is this file's counterpart for src/yelp.c.
#
# Adwaita::Application is broken in the Ruby bindings (see the ruby-gtk
# skill), so this is a Gtk::Application; every window it opens is still an
# Adwaita::ApplicationWindow.
class Application < Gtk::Application
  APP_ID = 'org.rubygtkproject.Yelp'

  # Mirrors yelp_application_init's gtk_application_set_accels_for_action
  # calls. Upstream's navigation accelerators (go-back/forward/previous/next,
  # win.yelp-view-print) belong to YelpView, which is a separate porting
  # track from this file, so they are not set here yet.
  ACCELS = {
    'app.yelp-application-show-cursor'  => ['F7'],
    'app.yelp-application-larger-text'  => ['<Control>plus'],
    'app.yelp-application-smaller-text' => ['<Control>minus'],
    'win.yelp-window-new'               => ['<Control>n'],
    'win.yelp-window-close'             => ['<Control>w'],
  }.freeze

  STYLESHEET_PATH = File.join(__dir__, 'style.css')

  def initialize
    super(APP_ID, :default_flags)
    signal_connect('startup') { startup }
    signal_connect('activate') { new_window }
  end

  def build = self

  # The windows this application has open — upstream's `priv->windows`,
  # backed here by Gtk::Application's own list rather than a duplicate.
  def windows = super.to_a

  def new_window
    Window.new(self).tap do |window|
      add_window(window)
      window.present
    end
  end

  def doc_settings = @doc_settings ||= Gio::Settings.new('org.gnome.yelp.documents')

  # Ported from libyelp/yelp-bookmarks.c / .h's YelpBookmarksInterface, which
  # yelp_application_iface_init installs onto YelpApplication in upstream —
  # add_bookmark/remove_bookmark/is_bookmarked, backed here by the
  # "bookmarks" key in org.gnome.yelp.documents (a(sss): page id, icon,
  # title). Every open window is told when a document's stored bookmarks
  # change, the way upstream's windows all watch the same "bookmarks-changed"
  # signal yelp_application_update_bookmarks emits.
  #
  # Upstream keys a separate GSettings instance per document URI
  # (application_get_doc_settings, a GKeyfileSettingsBackend per URI); gio2
  # has no g_settings_new_full/with_path binding (see lib/settings.rb's
  # header), so — exactly like lib/window.rb's "geometry" read — this port
  # shares one fixed-path GSettings across every document instead. `doc_uri`
  # is kept on every method below for parity with upstream's signatures even
  # though it does not yet select which GSettings instance is read.
  def add_bookmark(doc_uri, page_id, icon, title)
    tuples = bookmark_tuples
    if tuples.none? { |this_id, _, _| this_id == page_id }
      write_bookmark_tuples(tuples + [[page_id, icon, title]])
      notify_bookmarks_changed(doc_uri)
    end
  end

  def remove_bookmark(doc_uri, page_id)
    write_bookmark_tuples(bookmark_tuples.reject { |this_id, _, _| this_id == page_id })
    notify_bookmarks_changed(doc_uri)
  end

  def bookmarked?(_doc_uri, page_id)
    bookmark_tuples.any? { |this_id, _, _| this_id == page_id }
  end

  def bookmarks(_doc_uri)
    bookmark_tuples.map { |page_id, icon, title| Bookmark.new(page_id, icon, title) }
  end

  private

    # The Ruby gio2 binding cannot build an `a(sss)` GVariant from a plain
    # Ruby array (GLib::Variant.new raises NotImplementedError for
    # tuple-typed container values), and Gio::Settings#set_value always
    # rewraps its argument through that same unimplemented path, so
    # bookmarks are written via GVariant text format (GLib::Variant.parse)
    # through Gio::Settings#set_value_raw, which skips the rewrap. Reading
    # back is unaffected — gio2 already converts an `a(sss)` GVariant to a
    # plain Ruby array of 3-string arrays.
    def bookmark_tuples = doc_settings.get_value('bookmarks')

    def write_bookmark_tuples(tuples)
      doc_settings.set_value_raw('bookmarks', bookmark_variant(tuples))
    end

    def bookmark_variant(tuples)
      body = tuples.map { |a, b, c| "(#{variant_string(a)}, #{variant_string(b)}, #{variant_string(c)})" }.join(', ')
      GLib::Variant.parse("[#{body}]", 'a(sss)')
    end

    def variant_string(value) = "'#{value.to_s.gsub('\\', '\\\\\\\\').gsub("'", "\\\\'")}'"

    def notify_bookmarks_changed(doc_uri)
      windows.each { |window| window.bookmarks_changed(doc_uri) }
    end

    # Ported from yelp_application_startup. I have not ported the
    # per-document `GKeyfileSettingsBackend` setup (see the class comment
    # above) or registration of the YelpBookmarks D-Bus interface that
    # upstream's startup also does here. Registering src/style.css as a
    # Gtk::CssProvider is the
    # one piece of upstream's startup this port's chrome already depends
    # on: lib/window.rb applies the `yelp-find-frame` class it defines.
    # 600 is GTK_STYLE_PROVIDER_PRIORITY_APPLICATION; the Ruby bindings do
    # not expose it as a constant, so it is passed as the literal GTK uses.
    STYLE_PROVIDER_PRIORITY_APPLICATION = 600

    def startup
      install_accels
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        stylesheet,
        STYLE_PROVIDER_PRIORITY_APPLICATION,
      )
    end

    def stylesheet
      @stylesheet ||= Gtk::CssProvider.new.tap { |provider| provider.load_from_path(STYLESHEET_PATH) }
    end

    def install_accels
      install_actions
      ACCELS.each { |action, accels| set_accels_for_action(action, accels) }
    end

    def install_actions
      add_action(show_cursor_action)
      add_action(larger_text_action)
      add_action(smaller_text_action)
      add_action(reset_text_size_action)
    end

    # Mirrors upstream's `show_cursor_action`, a GPropertyAction bound to
    # YelpSettings#show-text-cursor. This port's Settings is a plain Ruby
    # object rather than a GObject, so there is no property for a
    # Gio::PropertyAction to bind to; a stateful Gio::SimpleAction that
    # flips Settings.default.show_text_cursor on activation does the same
    # job.
    def show_cursor_action
      @show_cursor_action ||= Gio::SimpleAction.new(
        'yelp-application-show-cursor',
        nil,
        GLib::Variant.new(Settings.default.show_text_cursor?),
      ).tap do |action|
        action.signal_connect('activate') do
          Settings.default.show_text_cursor = !Settings.default.show_text_cursor?
          action.change_state(GLib::Variant.new(Settings.default.show_text_cursor?))
        end
      end
    end

    def larger_text_action
      @larger_text_action ||= Gio::SimpleAction.new('yelp-application-larger-text', nil).tap do |action|
        action.signal_connect('activate') do
          Settings.default.zoom_level += 0.1
          refresh_zoom_labels
        end
      end
    end

    def smaller_text_action
      @smaller_text_action ||= Gio::SimpleAction.new('yelp-application-smaller-text', nil).tap do |action|
        action.signal_connect('activate') do
          Settings.default.zoom_level -= 0.1
          refresh_zoom_labels
        end
      end
    end

    def reset_text_size_action
      @reset_text_size_action ||= Gio::SimpleAction.new('yelp-application-reset-text-size', nil).tap do |action|
        action.signal_connect('activate') do
          Settings.default.zoom_level = 1.0
          refresh_zoom_labels
        end
      end
    end

    # The zoom-controls row each window's PrimaryMenu holds is a plain
    # Gtk::Label, not something bound live to the `zoom-level` GSettings key
    # (see lib/primary_menu.rb's `refresh`), so every action above that
    # changes `Settings.default.zoom_level` has to tell every open window's
    # menu to re-read it — mirroring upstream's views, which all watch the
    # same `YelpSettings` singleton and redraw on its "zoom-level" notify.
    def refresh_zoom_labels
      windows.each { |window| window.primary_menu.refresh }
    end
end
