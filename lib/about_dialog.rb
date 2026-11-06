# frozen_string_literal: true

require 'adwaita'

# AboutDialog is the "About Help" dialog, reachable from the primary menu.
#
# Ported from upstream's present_about_dialog in src/yelp-window.c, which
# calls adw_show_about_dialog with a fixed set of fields. This port builds
# the same Adw.AboutDialog directly rather than through that convenience
# function, since the convenience function is a one-shot present and this
# port's house style builds every dialog as a memoized, inspectable object.
#
class AboutDialog < Adwaita::AboutDialog
  DEVELOPERS = [
    'Shaun McCance <shaunm@gnome.org>',
    'Mikael Hallendal <micke@imendio.com>',
    'Alexander Larsson <alexl@redhat.com>',
    'Brent Smith <gnome@nextreality.net>',
    'Don Scorgie <Don@Scorgie.org>',
    'David King <amigadave@amigadave.com>',
  ].freeze

  def initialize(version)
    super()
    self.application_name = 'Help'
    self.application_icon = 'org.gnome.Yelp'
    self.website = 'https://apps.gnome.org/Yelp'
    self.issue_url = 'https://gitlab.gnome.org/GNOME/yelp/issues'
    self.license_type = :gpl_2_0
    self.developer_name = 'The GNOME Project'
    self.developers = DEVELOPERS
    self.version = version
  end
end
