# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
schema_dir = File.expand_path('../data/schemas', __dir__)
ENV['GSETTINGS_SCHEMA_DIR'] = schema_dir
system('glib-compile-schemas', schema_dir, exception: true)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative 'gtk_driver'
require 'main'

GtkDriver.drive(Application.new, shots: 'tmp/shots') do |d, app|
  d.window { app.windows.first }

  d.step('window opens') do
    d.check('one window') { app.windows.size == 1 }
    d.check('default address') { app.windows.first.current_uri == Window::DEFAULT_URI }
    d.shot('01-initial')
  end

  d.step('open the primary menu') do
    window = app.windows.first
    window.menu_button.popover.popup
  end

  d.step('menu is open') do
    window = app.windows.first
    d.check('zoom label shows 100%') { window.primary_menu.zoom_label.label == '100%' }
    d.shot('02-primary-menu')
    window.menu_button.popover.popdown
  end

  d.step('press Ctrl+L and check the address bar') do
    window = app.windows.first
    window.activate_action('yelp-window-ctrll', nil)
  end

  d.step('address bar is showing') do
    window = app.windows.first
    d.check('title widget swapped to an entry') { window.header_bar.title_widget.is_a?(Gtk::Entry) }
    d.check('entry pre-filled with the current address') do
      window.header_bar.title_widget.text == Window::DEFAULT_URI
    end
    d.shot('03-address-bar')
  end

  d.step('add a bookmark for the current page') do
    window = app.windows.first
    window.bookmark_menu_button.popover.popup
    window.send(:bookmark_added)
  end

  d.step('bookmark shows up') do
    window = app.windows.first
    d.check('one bookmark') { window.instance_variable_get(:@bookmarks).size == 1 }
    d.check('remove button now visible') { window.bookmark_popover.remove_button.visible? }
    d.shot('04-bookmark-popover')
  end
end
