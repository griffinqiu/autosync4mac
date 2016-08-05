require 'rubygems'
require 'net/scp'
require 'ruby-growl'
require 'listen'
require 'yaml'

LOCK_FILE = '.lock4autosync'

if File.exist? LOCK_FILE
  p 'sync process is already running! This process will exit.'
  exit
end

# YAML::ENGINE.yamler = 'syck'

CONFIG = YAML::load(File.open("#{File.dirname(__FILE__)}/config.yml"))

$host = CONFIG['host']
$username = CONFIG['username']
$password = CONFIG['password']
$src_dir = CONFIG['src_dir']
$dest_dir = CONFIG['dest_dir']


$scp = Net::SCP.start($host, $username, :password => $password)
$growl = nil


#if Object.const_defined? :Growl
  #class UUID
    #def generate() 4 end
  #end
  #$growl = Growl::GNTP.new 'localhost', 'autosync4mac'
  #$growl.uuid = UUID.new
  #$growl.add_notification "autosync4mac", "Auto Sync 4 Mac Notification", "PNG", true
  #$growl.register
  #$growl.notify "autosync4mac", "welcome", "auto sync 4 mac is running now."
#end

def notify(type, msg)
  if $growl
    $growl.notify "autosync4mac", type, msg, 2, true
  end
end

def upload(source, destination, recursive=true)
  begin
    $scp.upload!(source, destination, :recursive => recursive)
    p "#{source} modified, synced to server!"
  rescue
    $scp = Net::SCP.start($host, $username, :password => $password)
    $scp.upload!(source, destination, :recursive => recursive)
    p "#{source} modified, synced to server!"
  end

  begin
    #config growl listen to network connection
    notify "File sync", "#{source} modified, synced to server!"
  rescue
    p $!
  end
end

File.open(LOCK_FILE, 'w').close

Kernel.at_exit do
  p "will delete lock file, exit."
  File.delete LOCK_FILE
  notify "error", "sync process exited!"
end

p "start listen for changes..."
Listen.to($src_dir) do |modified, added, removed|
  modified.concat(added).each do |candidate|
    unless /\.(git|svn|hg)/ =~ candidate
      upload candidate, $dest_dir + candidate.split($src_dir)[1], File.directory?(candidate)
    end
  end
end
