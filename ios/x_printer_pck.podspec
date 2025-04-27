Pod::Spec.new do |s|
  s.name             = 'x_printer_pck'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/eq-devs/x_printer_pck'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'EQ Devs' => 'info@eq-devs.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # ⚡️ 只保留这一组
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/PrinterSDK/*.h'
  s.vendored_libraries = 'Classes/PrinterSDK/*.a'
  # s.frameworks = 'UIKit', 'CoreBluetooth' # 如果需要蓝牙，取消注释
  s.static_framework = true

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end

 