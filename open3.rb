require 'open3'

stdout, stderr, status = Open3.capture3("./stun_probe")

puts stdout
puts stderr unless stderr.empty?