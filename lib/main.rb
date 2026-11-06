# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

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
# per-document GSettings objects; both exist to serve the document-loading
# pipeline in libyelp, which is a separate porting track from this file's
# window chrome, so this port's registry is the plain list `Gtk::Application`
# already keeps (`windows`) rather than a hand-rolled duplicate.
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

  def initialize
    super(APP_ID, :default_flags)
    signal_connect('startup') { install_accels }
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

  private

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
        action.signal_connect('activate') { Settings.default.zoom_level += 0.1 }
      end
    end

    def smaller_text_action
      @smaller_text_action ||= Gio::SimpleAction.new('yelp-application-smaller-text', nil).tap do |action|
        action.signal_connect('activate') { Settings.default.zoom_level -= 0.1 }
      end
    end

    def reset_text_size_action
      @reset_text_size_action ||= Gio::SimpleAction.new('yelp-application-reset-text-size', nil).tap do |action|
        action.signal_connect('activate') { Settings.default.zoom_level = 1.0 }
      end
    end
end
