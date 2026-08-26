#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gfmc_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gfmc_flutter'
  s.version          = '0.2.0'
  s.summary          = 'Flutter plugin wrapping GfmcSDK (JessicaSDK) for iOS.'
  s.description      = <<-DESC
Flutter plugin for GfmcSDK -- embeds the minicinema mini-program (streaming,
entitlements, top-ups) inside a Flutter app's iOS target via JessicaSDK.
                       DESC
  s.homepage         = 'https://github.com/BDN-ID/jessica-sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SLTR' => 'support@sltr.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.static_framework = true
  s.swift_version    = '5.0'
  # StoreKit is a system framework JessicaSDK itself depends on; nothing to
  # add on top of it beyond the two it drives its own UI/networking with.
  s.frameworks       = 'UIKit', 'WebKit', 'StoreKit'

  # JessicaSDK (native GfmcSDK for iOS -- https://github.com/BDN-ID/gfmc-ios)
  # ships as a binary XCFramework via Swift Package Manager only: no podspec,
  # no CocoaPods trunk entry. `prepare_command` downloads and checksum-verifies
  # the exact release this plugin is pinned to, then vendors it in, so
  # `pod install` on the host app is still the only step a consumer needs.
  #
  # Bump these two together, from a tag at
  # https://github.com/BDN-ID/gfmc-ios/releases and the `checksum:` in that
  # tag's own Package.swift -- don't take the checksum from anywhere else.
  jessica_sdk_version = '1.14.0'
  jessica_sdk_sha256  = '6dc6ec664045083797b20c59febf10d3aff03e9578e9b57a18d71b669265ec04'
  jessica_sdk_url     = "https://github.com/BDN-ID/gfmc-ios/releases/download/#{jessica_sdk_version}/JessicaSDK.xcframework.zip"

  s.prepare_command = <<-CMD
    set -e
    ZIP="JessicaSDK.xcframework.zip"
    curl -fsSL -o "$ZIP" "#{jessica_sdk_url}"
    ACTUAL_SHA256=$(shasum -a 256 "$ZIP" | cut -d ' ' -f1)
    if [ "$ACTUAL_SHA256" != "#{jessica_sdk_sha256}" ]; then
      echo "error: JessicaSDK.xcframework.zip checksum mismatch (expected #{jessica_sdk_sha256}, got $ACTUAL_SHA256) -- refusing to vendor an unverified binary" >&2
      exit 1
    fi
    rm -rf JessicaSDK.xcframework
    unzip -o -q "$ZIP"
    rm -f "$ZIP"
  CMD

  s.vendored_frameworks = 'JessicaSDK.xcframework'
end
