sources = [
  'main.py',
  'application.py',
  'window.py',
  'commands.py',
]

install_data(sources, install_dir: pkgdatadir)

launcher_conf = configuration_data()
launcher_conf.set('PYTHON', py_installation.full_path())
launcher_conf.set('VERSION', meson.project_version())
launcher_conf.set('PKGDATADIR', pkgdatadir)

configure_file(
  input: 'notepad.in',
  output: 'notepad',
  configuration: launcher_conf,
  install: true,
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)
