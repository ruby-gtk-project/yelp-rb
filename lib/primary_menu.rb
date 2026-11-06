# frozen_string_literal: true

require 'gtk4'

require_relative 'settings'

# PrimaryMenu is the hamburger menu off the window's header bar: window and
# page actions, the zoom-controls row, and the entry into AboutDialog.
#
# Ported from the `primary-menu` Gio.Menu and `primary_popover_menu` in
# src/yelp-window.ui. Upstream's zoom row is a `<child type="zoom-controls">`
# attached to a `custom` menu item by id; this port does the same thing with
# `Gtk::PopoverMenu#add_child`, since ruby-gnome's binding keeps that method
# even though it does not surface in `instance_methods` (it is defined
# directly from the GObject-Introspection typelib — call it anyway).
#
class PrimaryMenu < Gtk::PopoverMenu
  def initialize
    super(model)
    add_child(zoom_controls, 'zoom-controls')
  end

  def model
    @model ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, window_section)
      menu.append_section(nil, navigation_section)
      menu.append_section(nil, zoom_section)
      menu.append_section(nil, all_help_section)
      menu.append_section(nil, about_section)
    end
  end

  def window_section
    @window_section ||= Gio::Menu.new.tap do |section|
      section.append('New Window', 'win.yelp-window-new')
      section.append('Find in Page…', 'win.yelp-window-find')
      section.append('Print…', 'win.yelp-view-print')
    end
  end

  def navigation_section
    @navigation_section ||= Gio::Menu.new.tap do |section|
      section.append('Previous Page', 'win.yelp-view-go-previous')
      section.append('Next Page', 'win.yelp-view-go-next')
    end
  end

  def zoom_section
    @zoom_section ||= Gio::Menu.new.tap do |section|
      section.append_item(zoom_item)
    end
  end

  def zoom_item
    @zoom_item ||= Gio::MenuItem.new(nil, nil).tap do |item|
      item.set_attribute_value('custom', GLib::Variant.new('zoom-controls'))
    end
  end

  def all_help_section
    @all_help_section ||= Gio::Menu.new.tap do |section|
      section.append('All Help', 'win.yelp-window-go-all')
    end
  end

  def about_section
    @about_section ||= Gio::Menu.new.tap do |section|
      section.append('About Help', 'win.yelp-show-about-dialog')
    end
  end

  # The box swapped in for the "zoom-controls" custom menu item: shrink,
  # reset (showing the current percentage) and enlarge, each wired to the
  # window actions `window.rb` installs.
  def zoom_controls
    @zoom_controls ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.homogeneous = true
      box.margin_top = 3
      box.margin_bottom = 3

      box.append(shrink_button)
      box.append(reset_button.tap { |btn| btn.child = zoom_label })
      box.append(enlarge_button)
    end
  end

  def shrink_button
    @shrink_button ||= Gtk::Button.new(icon_name: 'zoom-out-symbolic').tap do |btn|
      btn.tooltip_text = 'Shrink Text'
      btn.action_name = 'app.yelp-application-smaller-text'
      btn.halign = :center
      btn.add_css_class('circular')
      btn.add_css_class('flat')
    end
  end

  def reset_button
    @reset_button ||= Gtk::Button.new.tap do |btn|
      btn.tooltip_text = 'Reset Size'
      btn.action_name = 'app.yelp-application-reset-text-size'
      btn.halign = :center
      btn.add_css_class('flat')
      btn.add_css_class('numeric')
    end
  end

  def enlarge_button
    @enlarge_button ||= Gtk::Button.new(icon_name: 'zoom-in-symbolic').tap do |btn|
      btn.tooltip_text = 'Enlarge Text'
      btn.action_name = 'app.yelp-application-larger-text'
      btn.halign = :center
      btn.add_css_class('circular')
      btn.add_css_class('flat')
    end
  end

  def zoom_label
    @zoom_label ||= Gtk::Label.new.tap do |label|
      label.width_chars = 5
      refresh_zoom_label(label)
    end
  end

  # Called by whatever changes the zoom level (the window's actions), so the
  # percentage in the menu always matches `Settings.default.zoom_level`.
  def refresh
    refresh_zoom_label(zoom_label)
  end

  private

    def refresh_zoom_label(label)
      label.label = "#{(Settings.default.zoom_level * 100).round}%"
    end
end
