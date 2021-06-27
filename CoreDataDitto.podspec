#
# Be sure to run `pod lib lint CoreDataDitto.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CoreDataDitto'
  s.version          = '0.1.0'
  s.summary          = 'An experimental library to bind CoreData changes and sync them through Ditto.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
An experimental library to sync CoreData objects that have primary keys across DittoSwift.
                       DESC

  s.homepage         = 'https://github.com/getditto/CoreDataDitto'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = {
      'Maximilian Alexander' => 'max@ditto.live',
      'Adam Fish' => 'adam@ditto.live',
      'Hamilton Chapman' => 'ham@ditto.live',
      'Thomas Karpiniec' => 'tom@ditto.live'
  }
  s.source           = { :git => 'https://github.com/getditto/CoreDataDitto.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/dittolive'
  s.swift_version = '4.0'
  s.ios.deployment_target = '13.0'

  s.source_files = 'CoreDataDitto/Classes/**/*'

  # s.resource_bundles = {
  #   'CoreDataDitto' => ['CoreDataDitto/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'CoreData'
  s.dependency 'DittoSwift', '~> 1.0.4'
  s.swift_version = '5.0'


  # DittoSwift isn't available for all simulator types
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
