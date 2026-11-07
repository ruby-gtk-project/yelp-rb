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
require 'error_page'

GtkDriver.drive(Application.new, shots: 'tmp/shots') do |d, app|
  d.window { app.windows.first }

  original_window = nil

  d.step('ErrorPage renders the three error kinds') do
    d.check('not found') { ErrorPage.new(message: 'x', code: ErrorPage::NOT_FOUND).html.include?('Page Not Found') }
    d.check('cant read') { ErrorPage.new(message: 'x', code: ErrorPage::CANT_READ).html.include?('Cannot Read') }
    d.check('unknown') { ErrorPage.new(message: 'x', code: ErrorPage::UNKNOWN).html.include?('Unknown Error') }
  end

  d.step('ErrorPage document-not-found adds the recovery link') do
    page = ErrorPage.new(
      message: 'missing', code: ErrorPage::NOT_FOUND,
      document_not_found: true, uri: 'help:gnome-help/foo',
    )
    d.check('title swaps to Document Not Found') { page.title == 'Document Not Found' }
    d.check('recovery link present') { page.html.include?('install-help:gnome-help/foo') }
    d.check('message escaped into the page') { page.html.include?('<p>missing</p>') }
  end

  d.step('ErrorPage escapes HTML-unsafe messages') do
    page = ErrorPage.new(message: %(<script>&"'</script>))
    d.check('message is escaped, not raw') { page.html.include?('&lt;script&gt;&amp;&quot;') }
    d.check('no recovery link without document_not_found') { !page.html.include?('install-') }
  end

  d.step('window opens') do
    d.check('one window') { app.windows.size == 1 }
    original_window = app.windows.first
    d.check('default address') { original_window.current_uri == Window::DEFAULT_URI }
    d.check('header title shows default address') do
      original_window.header_title.subtitle == Window::DEFAULT_URI
    end
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

  d.step('enlarge text from the menu button') do
    window = app.windows.first
    window.primary_menu.enlarge_button.activate
  end

  d.step('zoom label follows the new zoom level') do
    window = app.windows.first
    # Regression check: PrimaryMenu#refresh is only any good if the app
    # actually calls it when the zoom level it reads changes.
    d.check('settings zoom level increased') { Settings.default.zoom_level > 1.0 }
    d.check('menu label updated to match') do
      window.primary_menu.zoom_label.label == "#{(Settings.default.zoom_level * 100).round}%"
    end
  end

  d.step('reset text size from the app action') do
    app.activate_action('yelp-application-reset-text-size', nil)
  end

  d.step('zoom label back to 100% everywhere') do
    window = app.windows.first
    d.check('settings zoom level reset') { Settings.default.zoom_level == 1.0 }
    d.check('menu label reset too') { window.primary_menu.zoom_label.label == '100%' }
  end

  d.step('toggle the show-cursor app action') do
    action = app.lookup_action('yelp-application-show-cursor')
    d.check('starts off') { Settings.default.show_text_cursor? == false }
    action.activate(nil)
  end

  d.step('show-cursor state followed the toggle') do
    action = app.lookup_action('yelp-application-show-cursor')
    d.check('settings flipped on') { Settings.default.show_text_cursor? == true }
    d.check('action state followed') { action.state == true }
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

  d.step('Escape restores the plain title widget') do
    window = app.windows.first
    controller = window.send(:address_entry_key_controller)
    controller.signal_emit('key-pressed', Gdk::Keyval::KEY_Escape, 0, 0)
  end

  d.step('title widget is back to the window title') do
    window = app.windows.first
    d.check('title widget restored') { window.header_bar.title_widget.equal?(window.header_title) }
  end

  d.step('open the address bar again and load a new address') do
    window = app.windows.first
    window.activate_action('yelp-window-ctrll', nil)
    window.header_bar.title_widget.text = 'help:gnome-help/accessibility'
    window.header_bar.title_widget.signal_emit('activate')
  end

  d.step('address loaded from the entry') do
    window = app.windows.first
    d.check('current_uri updated') { window.current_uri == 'help:gnome-help/accessibility' }
    d.check('header subtitle updated') { window.header_title.subtitle == 'help:gnome-help/accessibility' }
    d.check('title widget restored after activate') { window.header_bar.title_widget.equal?(window.header_title) }
  end

  d.step('drop target is wired for text drops') do
    window = app.windows.first
    # The actual 'drop' signal carries a generic GObject::Value the Ruby
    # bindings give no way to construct from here (GLib::Value.new wants a
    # numeric GType, and there is no binding path from the `String` class to
    # one) — a real drag-and-drop session is what upstream gets this from,
    # and neither is available headlessly. What is drivable is the handler
    # itself, which is nothing but `load_uri(value)`; that path is already
    # covered by the address-bar steps above, so this checks only the
    # controller's own configuration.
    d.check('accepts String payloads') { window.drop_target.formats.gtypes.include?(GLib::Type["gchararray"]) }
    d.check('uses the copy action') { window.drop_target.actions == Gdk::DragAction::COPY }
    d.check('attached to the window') { window.observe_controllers.to_a.include?(window.drop_target) }
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
    d.check('add button now hidden') { !window.bookmark_popover.add_button.visible? }
    d.check('empty label hidden') { !window.bookmark_popover.empty_label.visible? }
    d.shot('04-bookmark-popover')
  end

  d.step('remove the bookmark from its row') do
    window = app.windows.first
    bookmark = window.instance_variable_get(:@bookmarks).first
    window.bookmark_popover.list_box.get_row_at_index(0).remove_button.activate
    _ = bookmark
  end

  d.step('bookmark list empty again') do
    window = app.windows.first
    d.check('no bookmarks left') { window.instance_variable_get(:@bookmarks).empty? }
    d.check('add button visible again') { window.bookmark_popover.add_button.visible? }
    d.check('remove button hidden again') { !window.bookmark_popover.remove_button.visible? }
    d.check('empty label visible again') { window.bookmark_popover.empty_label.visible? }
    window.bookmark_menu_button.popover.popdown
  end

  d.step('open the find bar from its window action') do
    window = app.windows.first
    window.activate_action('yelp-window-find', nil)
  end

  d.step('find bar is revealed and focused') do
    window = app.windows.first
    d.check('find bar revealed') { window.find_bar.reveal_child? == true }
    d.shot('05-find-bar')
  end

  d.step('close the find bar with its close button') do
    window = app.windows.first
    window.find_close_button.activate
  end

  d.step('find bar is hidden again') do
    window = app.windows.first
    d.check('find bar not revealed') { window.find_bar.reveal_child? == false }
  end

  d.step('seed a bookmark so the search completions have something to match') do
    window = app.windows.first
    window.send(:bookmark_added)
  end

  d.step('open search mode from the header toggle button') do
    window = app.windows.first
    window.search_button.active = true
  end

  d.step('search mode swapped the header title widget to the search entry') do
    window = app.windows.first
    d.check('title widget is the search entry clamp') do
      window.header_bar.title_widget.equal?(window.send(:search_entry_clamp))
    end
    d.shot('05b-search-mode')
  end

  d.step('type a query that matches the seeded bookmark') do
    window = app.windows.first
    window.search_entry.entry.text = window.current_uri
  end

  d.step('the completion popover shows the match') do
    window = app.windows.first
    d.check('popover is visible') { window.search_entry.popover.visible? }
    d.check('search-all row mentions the typed query') do
      window.search_entry.search_all_label.label.include?(window.current_uri)
    end
    d.check('one completion in the sliced model') { window.search_entry.send(:sliced_model).n_items == 1 }
    d.shot('05c-search-completions')
  end

  d.step('press Down to select the first completion row') do
    window = app.windows.first
    window.search_entry.send(:key_controller).signal_emit('key-pressed', Gdk::Keyval::KEY_Down, 0, 0)
  end

  d.step('the first row is now selected') do
    window = app.windows.first
    d.check('selection moved to index 0') { window.search_entry.send(:selection_model).selected.zero? }
  end

  d.step('press Escape once to close the popover without leaving search mode') do
    window = app.windows.first
    window.search_entry.send(:key_controller).signal_emit('key-pressed', Gdk::Keyval::KEY_Escape, 0, 0)
  end

  d.step('popover closed, search mode still active') do
    window = app.windows.first
    d.check('popover popped down') { !window.search_entry.popover.visible? }
    d.check('search button still active') { window.search_button.active? }
  end

  d.step('press Escape again to leave search mode entirely') do
    window = app.windows.first
    window.search_entry.send(:key_controller).signal_emit('key-pressed', Gdk::Keyval::KEY_Escape, 0, 0)
  end

  d.step('search mode closed by the second Escape') do
    window = app.windows.first
    d.check('search button deactivated') { !window.search_button.active? }
    d.check('title widget restored') { window.header_bar.title_widget.equal?(window.header_title) }
  end

  d.step('reopen search, select the row and activate it') do
    window = app.windows.first
    window.search_button.active = true
    window.search_entry.entry.text = window.current_uri
    window.search_entry.send(:key_controller).signal_emit('key-pressed', Gdk::Keyval::KEY_Down, 0, 0)
    window.search_entry.send(:entry_activate)
  end

  d.step('activating the selected completion loaded its page and left search mode') do
    window = app.windows.first
    d.check('search button deactivated') { !window.search_button.active? }
    d.check('title widget restored') { window.header_bar.title_widget.equal?(window.header_title) }
    d.check('popover popped down') { !window.search_entry.popover.visible? }
  end

  d.step('open search again, clear the query and use the standing "search for" row') do
    window = app.windows.first
    window.search_button.active = true
    window.search_entry.entry.text = 'help:gnome-help/accessibility'
    window.search_entry.send(:selection_model).unselect_item(0) if window.search_entry.send(:sliced_model).n_items.positive?
    window.search_entry.send(:search_all_row).activate
  end

  d.step('the search-for-everything row loaded the typed query and left search mode') do
    window = app.windows.first
    d.check('current_uri updated to the typed query') { window.current_uri == 'help:gnome-help/accessibility' }
    d.check('search button deactivated') { !window.search_button.active? }
    d.check('title widget restored') { window.header_bar.title_widget.equal?(window.header_title) }
  end

  d.step('clean up the seeded bookmark') do
    window = app.windows.first
    bookmark = window.instance_variable_get(:@bookmarks).first
    window.send(:bookmark_removed, bookmark)
  end

  d.step('bookmarks are empty again after cleanup') do
    window = app.windows.first
    d.check('no bookmarks left') { window.instance_variable_get(:@bookmarks).empty? }
  end

  d.step('open the About dialog from the window action') do
    window = app.windows.first
    window.activate_action('yelp-show-about-dialog', nil)
  end

  d.step('about dialog is visible') do
    window = app.windows.first
    d.check('a dialog is showing') { !window.visible_dialog.nil? }
    d.check('it is the AboutDialog') { window.visible_dialog.is_a?(AboutDialog) }
    d.check('app name is Help') { window.visible_dialog.application_name == 'Help' }
    d.shot('06-about-dialog')
    window.visible_dialog.close
  end

  d.step('about dialog closed') do
    window = app.windows.first
    d.check('no dialog showing') { window.visible_dialog.nil? }
  end

  d.step('open a new window with win.yelp-window-new') do
    window = app.windows.first
    window.activate_action('yelp-window-new', nil)
  end

  d.step('a second window opened') do
    d.check('two windows now') { app.windows.size == 2 }
    d.check('two toplevels') { Gtk::Window.list_toplevels.length == 2 }
    d.check('the new window defaults to the help URI, independent of the first') do
      (app.windows - [original_window]).first.current_uri == Window::DEFAULT_URI
    end
    d.shot('07-second-window')
  end

  d.step('close the second window with win.yelp-window-close') do
    (app.windows - [original_window]).first.activate_action('yelp-window-close', nil)
  end

  d.step('back down to one window') do
    d.check('one window again') { app.windows.size == 1 }
    d.check('the surviving window is the original') { app.windows.first.equal?(original_window) }
  end

  d.step('window is wide, before narrowing it') do
    window = app.windows.first
    d.check('bottom toolbar starts hidden') { !window.bottom_toolbar.visible? }
    d.check('back/forward buttons start visible in the header') { window.go_back_button.visible? }
    d.shot('08-wide')
  end

  d.step('narrow the window below the adaptive breakpoint') do
    window = app.windows.first
    window.default_width = 360
    window.default_height = 600
    window.queue_resize
  end

  d.step('the breakpoint applied its setters') do
    window = app.windows.first
    d.check('breakpoint is an Adwaita::Breakpoint') { window.send(:adaptive_breakpoint).is_a?(Adwaita::Breakpoint) }
    d.check('bottom toolbar now visible') { window.bottom_toolbar.visible? }
    d.check('header back button hidden') { !window.go_back_button.visible? }
    d.check('header forward button hidden') { !window.go_forward_button.visible? }
    d.shot('09-narrow')
  end
end
