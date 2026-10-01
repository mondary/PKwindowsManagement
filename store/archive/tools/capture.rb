#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'tmpdir'
require 'securerandom'
require 'cgi'

root = File.expand_path('../..', __dir__)
abort 'Usage: ruby store/tools/capture.rb [--search]' unless ARGV.empty? || ARGV == ['--search']
search = ARGV == ['--search']
temp = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode'
abort "Missing approved temporary directory: #{temp}" unless Dir.exist?(temp)
protected_files = Dir.glob("#{root}/src/**/*").select { |p| File.file?(p) } +
                  (search ? Dir.glob("#{root}/store/screenshots/*.png") :
                    %w[appearance.png shortcuts.png].map { |p| "#{root}/store/screenshots/#{p}" })
before = protected_files.to_h { |p| [p, Digest::SHA256.file(p).hexdigest] }
build = Dir.mktmpdir('pk-store-capture-', temp)
bundle = "#{build}/StoreCapture.app/Contents"
FileUtils.mkdir_p(["#{bundle}/MacOS", "#{bundle}/Resources", "#{build}/module-cache"])
identifier = "org.pk.storecapture.run-#{SecureRandom.uuid.downcase}"
version = File.read("#{root}/VERSION").strip
plist = {
  'CFBundleIdentifier' => identifier, 'CFBundleExecutable' => 'StoreCapture',
  'CFBundlePackageType' => 'APPL', 'CFBundleShortVersionString' => version,
  'CFBundleDevelopmentRegion' => 'en', 'LSUIElement' => true
}
File.write("#{bundle}/Info.plist", '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>' +
  plist.map { |k, v| "<key>#{k}</key>" + (v == true ? '<true/>' : "<string>#{CGI.escapeHTML(v)}</string>") }.join + '</dict></plist>')
FileUtils.cp_r(Dir.glob("#{root}/src/macos/Resources/*.lproj"), "#{bundle}/Resources")

# Swift private members are accessible to extensions in the same source file.
# Only the temporary compilation unit gets this extension; src stays untouched.
service = "#{build}/AppLauncherService.swift"
File.write(service, File.read("#{root}/src/macos/Services/AppLauncherService.swift") + "\n" + File.read("#{__dir__}/CatalogFixture.swift"))
sources = Dir.glob("#{root}/src/macos/**/*.swift").reject do |p|
  %w[PKwindowsManagementApp.swift MenuBarController.swift AppLauncherService.swift].include?(File.basename(p))
end
executable = "#{bundle}/MacOS/StoreCapture"
begin
  command = ['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
             '-module-cache-path', "#{build}/module-cache", '-o', executable,
             *sources, service, "#{__dir__}/Capture.swift"]
  abort 'Swift compilation failed' unless system(*command)
  output = search ? "#{build}/search-frames" : "#{root}/store/screenshots"
  FileUtils.mkdir_p(output)
  abort 'Native capture failed' unless system(executable, output, *ARGV,
                                             '-AppleLanguages', '(en)', '-app-language', 'en')
  if search
    videos = "#{root}/store/videos"
    abort "Missing output directory: #{videos}" unless Dir.exist?(videos)
    input = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '15', '-i', "#{output}/frame-%04d.png"]
    abort 'Palette generation failed' unless system(*input, '-vf', 'scale=900:-2:flags=lanczos,palettegen=stats_mode=diff', '-frames:v', '1', "#{output}/palette.png")
    abort 'GIF encoding failed' unless system(*input, '-i', "#{output}/palette.png", '-lavfi', '[0:v]scale=900:-2:flags=lanczos[v];[v][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle', '-loop', '0', "#{videos}/launchpad-search.gif")
    abort 'MP4 encoding failed' unless system(*input, '-vf', 'scale=900:-2:flags=lanczos', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', "#{videos}/launchpad-search.mp4")
    abort 'Poster encoding failed' unless system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', "#{output}/frame-0050.png", '-vf', 'scale=900:-2:flags=lanczos', '-frames:v', '1', "#{videos}/launchpad-search-poster.png")
    abort 'Contact sheet failed' unless system(*input, '-vf', "select='eq(n,0)+eq(n,25)+eq(n,37)+eq(n,50)+eq(n,85)+eq(n,91)+eq(n,100)',scale=450:-2,tile=4x2", '-frames:v', '1', "#{videos}/launchpad-search-contact.png")
    FileUtils.cp("#{output}/search-evidence.json", "#{videos}/launchpad-search-evidence.json")
    puts "Search capture: #{videos}/launchpad-search.gif (8 seconds, 900 px); native source frames: #{output}"
  end
ensure
  changed = before.keys.select { |p| !File.file?(p) || Digest::SHA256.file(p).hexdigest != before[p] }
  abort "Protected files changed during capture: #{changed.join(', ')}" unless changed.empty?
  puts "Verified src and protected screenshots unchanged. Build: #{build}"
end
