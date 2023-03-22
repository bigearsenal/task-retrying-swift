Pod::Spec.new do |s|
  s.name             = 'Task_retrying'
  s.version          = '2.0.0'
  s.summary          = 'Extension for Task for retrying operations.'
  
  s.description      = <<-DESC
The extension that allows you to make a retriable Task
                       DESC

  s.homepage         = 'https://github.com/bigearsenal/task-retrying-swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chung Tran' => 'bigearsenal@gmail.com' }
  s.source           = { :git => 'https://github.com/bigearsenal/task-retrying-swift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'Sources/Task_retrying/**/*'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'SWIFT_OPTIMIZATION_LEVEL' => '-O'
  }
end
