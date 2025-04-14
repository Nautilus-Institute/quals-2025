#!/usr/bin/env ruby

require 'base64'
require 'json'

hint = JSON.parse(File.read(File.join(__dir__, 'hint.json')))

remote = nil
ticket = nil

if File.executable?(ARGV[0])
  remote = IO.popen(ARGV[0], 'r+')
else
  addr = Addrinfo.tcp(*(ARGV[0].split(':')))
  remote = TCPSocket.new(addr)
  ticket = ARGV[1]
end

if ticket
  remote.puts ticket
end

puts remote.gets
remote.puts hint['index']
puts remote.gets

payload = hint['payload']

puts "solver encoded #{payload.size} bytes"

encoded_payload = Base64.strict_encode64(payload)
puts encoded_payload

puts remote.gets
remote.puts encoded_payload
remote.close_write
puts remote.gets
puts remote.gets

