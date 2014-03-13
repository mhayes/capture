pth = File.dirname(File.absolute_path(__FILE__))
root_pth = File.join(pth, "..")
worker_pth =  File.join(root_pth, "sqs_poll.rb")

God.watch do |w|
  w.dir = root_pth
  w.name = "capture_worker"
  w.start = "ruby sqs_poll.rb"
  w.keepalive
  w.log = "production.log"
end