# frozen_string_literal: true

require 'gio2'
require 'gtk4'

# Settings is the zoom/cursor/font behaviour shared by every window and view.
#
# Ported from upstream's libyelp/yelp-settings.c / .h, a process-wide
# singleton (`yelp_settings_get_default`) that every YelpView and YelpWindow
# reads from. Upstream's zoom level and show-text-cursor flag are bound
# straight through to the `org.gnome.yelp` GSettings schema
# (data/schemas/org.gnome.yelp.gschema.xml, carried over from
# data/org.gnome.yelp.gschema.xml), which this port does the same way with
# `Gio::Settings` read/write calls instead of upstream's `g_settings_bind`.
#
# Upstream's colour handling (YELP_SETTINGS_COLOR_BASE/TEXT, read from the
# Adwaita style manager) has no equivalent here — this port's views are
# styled by lib/style.css rather than injected CSS custom properties — so it
# is not carried over.
#
# Fonts are not stored by `org.gnome.yelp` at all: upstream reads them from
# GtkSettings (the variable font) and parses "Family Size" out of the string,
# falling back to "Sans"/10 and "Monospace"/10. This port reads the same two
# strings from `org.gnome.desktop.interface`, which is where the variable
# *and* monospace font names actually live on GNOME (GtkSettings only
# exposes the variable one), and parses them the same way.
class Settings
  ZOOM_LEVEL_MIN = 0.5
  ZOOM_LEVEL_MAX = 4.0

  DEFAULT_FONTS = {
    variable: 'Sans 10',
    fixed:    'Monospace 10',
  }.freeze

  class << self
    def default = @default ||= new
  end

  def gsettings = @gsettings ||= Gio::Settings.new('org.gnome.yelp')

  def desktop_settings = @desktop_settings ||= Gio::Settings.new('org.gnome.desktop.interface')

  def zoom_level = gsettings.get_double('zoom-level')

  def zoom_level=(value)
    gsettings.set_double('zoom-level', value.clamp(ZOOM_LEVEL_MIN, ZOOM_LEVEL_MAX))
  end

  def show_text_cursor? = gsettings.get_boolean('show-cursor')

  def show_text_cursor=(value)
    gsettings.set_boolean('show-cursor', value)
  end

  def font(variable: true) = variable ? variable_font : fixed_font

  def font_family(variable: true) = parse_font(font(variable: variable)).first

  def font_size(variable: true) = parse_font(font(variable: variable)).last

  private

    def variable_font
      desktop_settings.get_string('font-name').then { |name| name.empty? ? DEFAULT_FONTS[:variable] : name }
    end

    def fixed_font
      desktop_settings.get_string('monospace-font-name').then do |name|
        name.empty? ? DEFAULT_FONTS[:fixed] : name
      end
    end

    def parse_font(description)
      description.rpartition(' ').then do |family, _sep, size|
        [family, [size.to_i, 5].max]
      end
    end
end
