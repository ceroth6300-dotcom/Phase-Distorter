
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  enable_language(OBJCXX)

  add_executable(phase_ios MACOSX_BUNDLE
    "${CMAKE_SOURCE_DIR}/ios/PhaseApp.mm"
  )

  target_compile_features(phase_ios PRIVATE cxx_std_20)

  target_include_directories(phase_ios PRIVATE
    "${CMAKE_SOURCE_DIR}/cpp/include"
    "${CMAKE_SOURCE_DIR}/generated"
  )

  target_link_libraries(phase_ios PRIVATE
    eb_session
    eb_assets
    eb_native_asset_profiles
    "-framework UIKit"
    "-framework Foundation"
    "-framework CoreGraphics"
    "-framework QuartzCore"
    "-framework UniformTypeIdentifiers"
  )

  set_target_properties(phase_ios PROPERTIES
    OUTPUT_NAME PhaseDistorter
    MACOSX_BUNDLE_INFO_PLIST
      "${CMAKE_SOURCE_DIR}/ios/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.0"
  )
endif()
