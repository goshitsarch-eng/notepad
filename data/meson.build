install_data(
  '@0@.desktop'.format(app_id),
  install_dir: get_option('datadir') / 'applications',
)

install_data(
  '@0@.metainfo.xml'.format(app_id),
  install_dir: get_option('datadir') / 'metainfo',
)

install_data(
  'icons' / 'hicolor' / 'scalable' / 'apps' / '@0@.svg'.format(app_id),
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test(
    'validate-desktop',
    desktop_utils,
    args: [meson.current_source_dir() / '@0@.desktop'.format(app_id)],
  )
endif
