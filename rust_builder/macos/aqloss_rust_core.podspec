Pod::Spec.new do |s|
  s.name             = 'aqloss_rust_core'
  s.version          = '0.3.0'
  s.summary          = 'Audio, uncompromised.'
  s.description      = <<-DESC
Aqloss is a music player built around a Rust audio engine, with optional WASAPI Exclusive mode on Windows for bit-perfect output to compatible hardware.
                       DESC
  s.homepage         = 'http://nokarin.xyz/projects/aqloss'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Strivo Development' => 'contact@nokarin.my.id' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.swift_version = '5.0'

  s.frameworks = 'CoreAudio', 'AudioToolbox'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../rust aqloss_rust_core',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libaqloss_rust_core.a"],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -force_load ${BUILT_PRODUCTS_DIR}/libaqloss_rust_core.a',
  }
end