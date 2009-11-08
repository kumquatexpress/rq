
require 'net/http'
require 'uri'
require 'fileutils'

# Shutdown queumgr
p 'Shutdown queuemgr'
r = `ruby ./code/queuemgr_ctl.rb stop`
sleep 0.2
p "Shutdown result: #{r}"

p 'Removing install directories'
FileUtils.rm_rf('./queue.noindex')
FileUtils.rm_rf('./queue')
FileUtils.rm_rf('./config')

#http = Net::HTTP.new('127.0.0.1', 3333)

def fetch(uri_str, limit = 10)
  # You should choose better exception.
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  
  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

def post(uri_str, limit = 10)
  # You should choose better exception.
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  
  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

# See if we are in a Clean State
resp = fetch("http://127.0.0.1:3333/")

p resp
if resp.body =~ /Your app is not setup\./
  p "System is in a clean state for an install"
else
  p "System is already in an installed state."
  exit 0
end

# Start the Install
p 'Starting install'
resp = Net::HTTP.post_form(URI.parse('http://127.0.0.1:3333/install'), {})

if resp.body =~ /Your app is now setup\./
  p "System is in a clean state for creating queues"
else
  p "System needs to be in a clean state before creating queues"
  exit 0
end

# Start queuemgr
p 'Starting queumgr'
r = `ruby ./code/queuemgr_ctl.rb start`
sleep 0.2
p "Startup result: #{r}"

# Check queumgr is up

is_up = false
5.times do
  resp = fetch("http://127.0.0.1:3333/")
  if resp.body =~ /QUEUE MGR is OPERATIONAL/
    is_up = true
    break
  end
  p "Not ready, retrying..."
  sleep 1.0
end

if is_up
  p "System is installed and queuemgr is up"
else
  p "System is installed and queuemgr is not up"
  exit 0
end

# Create the relay queue
resp = Net::HTTP.post_form(URI.parse('http://127.0.0.1:3333/new_queue'), {
                             'queue[url]' => 'http://localhost:3333/',  # TODO: hardcoded for now
                             'queue[name]' => 'relay',
                             'queue[script]' => './code/relay_script.rb',
                             'queue[ordering]' => 'ordered',
                             'queue[num_workers]' => '1',
                             'queue[fsync]' => 'fsync',
                           })

if resp.body =~ /successqueue created/
  p "System created relay queue"
else
  p "System did not create relay queue"
  exit 0
end

# Create the test1 queue
resp = Net::HTTP.post_form(URI.parse('http://127.0.0.1:3333/new_queue'), {
                             'queue[url]' => 'http://localhost:3333/',  # TODO: hardcoded for now
                             'queue[name]' => 'test',
                             'queue[script]' => './code/test/test_script.rb',
                             'queue[ordering]' => 'ordered',
                             'queue[num_workers]' => '1',
                             'queue[fsync]' => 'fsync',
                           })

if resp.body =~ /successqueue created/
  p "System created test queue"
else
  p "System did not create test queue"
  exit 0
end


p "ALL DONE SUCCESSFULLY"

exit 0
