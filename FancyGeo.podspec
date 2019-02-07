Pod::Spec.new do |s|

  s.name         = "FancyGeo"

  s.version      = "0.0.3"

  s.summary      = "A Fancy GeoLocation library"

  s.homepage     = "https://github.com/triniwiz/fancy-geo-ios"


  s.license      = { :type => "MIT", :file => "LICENSE" }


  s.author             = { "Osei Fortune" => "fortune.osei@yahoo.com" }

  s.platform     = :ios, "9.0"


  s.source       = { :git => "https://github.com/triniwiz/fancy-geo-ios.git", :tag => "#{s.version}" }

  s.source_files  = "Sources/FancyGeo/*.{swift}"

  s.frameworks = "CoreLocation", "UserNotifications"

  s.swift_version = '4.0'

end
