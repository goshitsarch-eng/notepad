project(
  'notepad',
  version: '1.0.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.62.0',
)

python = import('python')
py_installation = python.find_installation('python3')

app_id = 'com.gosharch.NotePad'
pkgdatadir = get_option('prefix') / get_option('datadir') / 'notepad'

subdir('src')
subdir('data')

test(
  'commands',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_commands.py'],
  env: {'PYTHONPATH': meson.project_source_root() / 'src'},
  workdir: meson.project_source_root(),
)

gnome = import('gnome')
gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
