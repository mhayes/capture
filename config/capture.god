pth = File.dirname(File.absolute_path(__FILE__))
root_pth = File.join(pth, "..")
worker_pth =  File.join(root_pth, "sqs_poll.rb")

%w{8200 8201 8202 8203 8204 8205}.each do |port|
  God.watch do |w|
    w.dir = root_pth
    w.name = "capture-worker-#{port}"
    w.start = "ruby sqs_poll.rb"
    w.keepalive
    w.log = "production.log"
  end
end