#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'base64'
require 'securerandom'
require 'openssl'
require 'digest/sha2'
require 'optparse'
require 'pp'
require 'ostruct'

# Constants

SSL_VERIFY_MODE = OpenSSL::SSL::VERIFY_NONE # CM uses a self-signed cert. Change to VERIFY_PEER if
                                            # that changes, or if you add their root CA.


def get_code(phone_number)
  uri = URI.parse("https://textsecure-service.whispersystems.org/v1/accounts/sms/code/#{phone_number}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = SSL_VERIFY_MODE
  request = Net::HTTP::Get.new(uri.request_uri)
  # Send synchronously
  response = http.request(request)
  return response.code
end

def validate_code(phone_number, verification_code, push_password, aes_key, hmac_key, registration_id)
  uri = URI.parse("https://textsecure-service.whispersystems.org/v1/accounts/code/#{verification_code}")
  pp uri
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = SSL_VERIFY_MODE
  request = Net::HTTP::Put.new(uri.request_uri)
  # Headers
  request.basic_auth(phone_number, push_password)
  request["Content-Type"] = "application/json"
  request["Accept"] = "application/json"
  # Body
  signaling_key = Base64.encode64(aes_key + hmac_key)
  body_hash = {
                signalingKey: signaling_key,
                supportsSms: true,
                registrationId: registration_id,
              }
  request.body = JSON.dump(body_hash)
  # Send synchronously
  response = http.request(request)
  return response.code
end

def unregister_number(phone_number, push_password, push_type, num_rounds=20)
  if ((push_type == :gcm) or (push_type == :apn))
    uri = URI.parse("https://textsecure-service.whispersystems.org/v1/accounts/#{push_type}")
  else
    abort("Invalid push type")
  end
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = SSL_VERIFY_MODE
  request = Net::HTTP::Delete.new(uri.request_uri)
  request.basic_auth(phone_number, push_password)
  current_round = 0
  print "Unregistering #{push_type} with #{num_rounds} rounds"
  num_rounds.times do
    sleep 1
    current_round += 1
    response = http.request(request)
    print "."
  end
  puts "done."
end

options = OpenStruct.new

OptionParser.new do |opts|
  opts.banner = "Usage: ./textsecure_unregister.rb [options]\n\n" +
                "EXAMPLES:\n" +
                "./textsecure_unregister.rb --mode getconfirm --phone-number +16501231234\n" +
                "./textsecure_unregister.rb --mode unregister --phone-number +16501231234 --code 123456\n" +
                "\n\n"
  opts.on("-m", "--mode MODE", [:getconfirm, :unregister],
              "Execution mode (getconfirm or unregister)") do |m|
        options.execution_mode = m
  end
  opts.on("-p", "--phone-number PHONE_NUMBER",
              "Phone number with leading + and country code",
              "Examples: +16505551234 +442071231234") do |phone_number|
        options.phone_number = phone_number
  end
    opts.on("-c", "--code VALIDATION_CODE",
              "Validation code received by SMS after --mode getconfirm",
              "without any dashes (example: 123456)") do |validation_code|
        options.validation_code = validation_code
  end
  # Set default for push_provider
  options.push_provider = :both
  opts.on("-t", "--type PUSH_PROVIDER", [:apn, :gcm, :both],
              "Deregister Android ('gcm') or Apple ('apn') endpoints,",
              "or both (default 'both', don't change unless you know",
              "what you're doing and why you want to change this)") do |push_provider|
        options.push_provider = push_provider
  end
end.parse!

if not options.execution_mode
  abort("You must specify an execution mode (try running with --help)")
end

if ((options.execution_mode == :unregister) and (not options.validation_code))
  abort("You must specify a validation code to unregister (try running with --help)")
end

if (options.validation_code)
  options.validation_code.gsub!(/[^0-9]/, '')
end

if not options.phone_number
  abort("You must specify a phone number (try running with --help)")
end

if /^\+?\d{10,14}$/.match(options.phone_number).nil?
  abort("You must specify an E.164 formatted phone number\nExamples: +16505551234 +442071231234")
end

if options.execution_mode == :getconfirm
  result = get_code(options.phone_number)
  if result[0..1] == "20"
    puts "Confirmation code sent to #{options.phone_number}. Run with -m unregister when you have it."
  else
    abort("Confirmation code not sent (try again, check syntax with --help)")
  end
elsif options.execution_mode == :unregister
  # Generate deterministic keys based on phone number
  # Security is not exactly paramount here as we're only registering to unregister
  digest = Digest::SHA512.digest(options.phone_number)
  seed = 0
  digest.each_byte do |byte|
    seed += byte
  end
  prng = Random.new(seed)
  registration_id = prng.rand(16384) # 14-bit positive int
  aes_key = prng.bytes(32) # 32 byte AES key
  hmac_key = prng.bytes(20) # 20 byte HMAC-SHA1 key
  push_password = Digest::SHA256.hexdigest(options.phone_number)[0..16] # 16 character text string
  result = validate_code(options.phone_number, options.validation_code, push_password,
                          aes_key, hmac_key, registration_id)
  if result[0..1] != "20"
    abort("Code did not validate (try again, check syntax with --help)")
  else
    sleep 1
    if options.push_provider == :both
      unregister_number(options.phone_number, push_password, :gcm, 20)
      unregister_number(options.phone_number, push_password, :apn, 20)
    elsif options.push_provider == :gcm
      unregister_number(options.phone_number, push_password, :gcm, 20)
    elsif options.push_provider == :apn
      unregister_number(options.phone_number, push_password, :apn, 20)
    end
    puts "You should now be unregistered from OpenWhispersystems's textsecure service."
  end
end

