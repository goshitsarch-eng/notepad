project(
  'notepad',
  version: '2.0.3',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.62.0',
)

python = import('python')
py_installation = python.find_installation('python3')

app_id = 'com.goshapps.Notepad'
pkgdatadir = get_option('prefix') / get_option('datadir') / 'notepad'

subdir('src')
subdir('data')

test_env = environment()
test_env.set('PYTHONPATH', meson.project_source_root() / 'src')
test_env.set('QT_QPA_PLATFORM', 'offscreen')

test(
  'commands',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_commands.py'],
  env: test_env,
  workdir: meson.project_source_root(),
)

test(
  'theme',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_theme.py'],
  env: test_env,
  workdir: meson.project_source_root(),
)

test(
  'window',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_window.py'],
  env: test_env,
  workdir: meson.project_source_root(),
)

test(
  'application',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_application.py'],
  env: test_env,
  workdir: meson.project_source_root(),
)

test(
  'packaging',
  py_installation,
  args: [meson.project_source_root() / 'tests' / 'test_packaging.py'],
  env: test_env,
  workdir: meson.project_source_root(),
)

gnome = import('gnome')
if find_program('update-desktop-database', required: false).found()
  gnome.post_install(
    gtk_update_icon_cache: false,
    update_desktop_database: true,
  )
endif
