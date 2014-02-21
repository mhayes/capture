#!/usr/bin/env ruby

require "bundler"
Bundler.require
puts Dotenv.load(File.join(File.absolute_path(File.dirname(__FILE__)), ".env"))

require 'json'
require 'securerandom'
require 'pathname'
require 'digest'

ROOT_PATH = Pathname.new(File.absolute_path(File.join(File.dirname(__FILE__))))
BIN_PATH = ROOT_PATH.join("bin")
CAPTURES_PATH = ROOT_PATH.join("captures")

class Page
  def initialize(json)
    @id = json["id"]
    @url = json["url"]
    @selector = json["selector"]
    @width = json["width"]
    @uuid = SecureRandom.uuid
  end

  attr_reader :uuid, :id, :url, :selector, :width, :depository_url, :depository_md5

  def cmd
    run_cmd = "#{BIN_PATH.join("webkit2png")} -F -W #{width} -D #{CAPTURES_PATH} -o #{uuid}"
    if @selector
      run_cmd += " --selector=\"#{@selector}\""
    end
    run_cmd += " #{url}"
  end

  def capture!
    success = system(cmd())
    return false if !success
    img_pth = CAPTURES_PATH.join("#{uuid}-full.png")
    success = system("pngquant #{img_pth}")
    return false if !success
    fs8_img_pth = "#{File.basename(img_pth, '.png')}-fs8.png"
    @depository_url = "#{ENV['HOST']}/#{fs8_img_pth}"
    @depository_md5 = Digest::MD5.file(CAPTURES_PATH.join(fs8_img_pth)).hexdigest
    self
  end

  def to_json(options={})
    {
      id: id,
      url: url,
      selector: selector,
      width: width,
      depository_url: depository_url,
      depository_md5: depository_md5
    }.to_json
  end
end

sqs = AWS::SQS.new
opts = {wait_time_seconds: 10}
capture_queue = sqs.queues[ENV["SQS_CAPTURE_QUEUE"]]
outbound_capture_queue = sqs.queues[ENV["SQS_OUTBOUND_CAPTURE_QUEUE"]]
outbound_comparison_queue = sqs.queues[ENV["SQS_OUTBOUND_COMPARISON_QUEUE"]]

capture_queue.poll(opts) do |msg|
  puts "CaptureQueue: #{msg.body.inspect}"
  page = Page.new(JSON.parse(msg.body))
  if page.capture!
    outbound_capture_queue.send_message(page.to_json)
    puts "Captured: #{page.to_json}"
  end
end