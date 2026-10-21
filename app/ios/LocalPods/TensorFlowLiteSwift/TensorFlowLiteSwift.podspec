# Local copy of TensorFlow Lite's Swift wrapper at v2.12.0 (the version tflite_flutter pins).
# The upstream podspec clones the whole TensorFlow repository (several GB) to get these
# 11 files; this vendors them instead. Sources and LICENSE are unmodified from
# https://github.com/tensorflow/tensorflow/tree/v2.12.0/tensorflow/lite/swift (Apache-2.0).
Pod::Spec.new do |s|
  s.name             = 'TensorFlowLiteSwift'
  s.version          = '2.12.0'
  s.authors          = 'Google Inc.'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.homepage         = 'https://github.com/tensorflow/tensorflow'
  s.source           = { :path => '.' }
  s.summary          = 'TensorFlow Lite for Swift'

  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.module_name = 'TensorFlowLite'
  s.static_framework = true
  s.default_subspec = 'Core'

  s.subspec 'Core' do |core|
    core.dependency 'TensorFlowLiteC', "#{s.version}"
    core.source_files = 'Sources/*.swift'
    core.exclude_files = 'Sources/{CoreML,Metal}Delegate.swift'
  end

  s.subspec 'CoreML' do |coreml|
    coreml.source_files = 'Sources/CoreMLDelegate.swift'
    coreml.dependency 'TensorFlowLiteC/CoreML', "#{s.version}"
    coreml.dependency 'TensorFlowLiteSwift/Core', "#{s.version}"
  end

  s.subspec 'Metal' do |metal|
    metal.source_files = 'Sources/MetalDelegate.swift'
    metal.dependency 'TensorFlowLiteC/Metal', "#{s.version}"
    metal.dependency 'TensorFlowLiteSwift/Core', "#{s.version}"
  end
end
