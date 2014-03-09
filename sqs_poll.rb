#!/usr/bin/env ruby

require "bundler"
Bundler.require

require 'json'
require 'securerandom'
require 'pathname'
require 'digest'

Dotenv.load(File.join(File.absolute_path(File.dirname(__FILE__)), ".env"))

ROOT_PATH = Pathname.new(File.absolute_path(File.join(File.dirname(__FILE__))))
BIN_PATH = ROOT_PATH.join("bin")
CAPTURES_PATH = ROOT_PATH.join("captures")

class Page
  def initialize(sqs, json)
    @id = json["id"]
    @url = json["url"]
    @selector = json["selector"]
    @width = json["width"]
    @uuid = SecureRandom.uuid
    queue = json["outbound_capture_queue_url"] || ENV["SQS_OUTBOUND_CAPTURE_QUEUE"]
    puts "Using queue: #{queue}"
    @outbound_queue = sqs.queues[queue]
  end

  attr_reader :uuid, :id, :url, :selector, :width, :depository_url, 
    :depository_md5, :outbound_queue

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

capture_queue.poll(opts) do |msg|
  puts "CaptureQueue: #{msg.body.inspect}"
  page = Page.new(sqs, JSON.parse(msg.body))
  if page.capture!
    page.outbound_queue.send_message(page.to_json)
    puts "Captured: #{page.to_json}"
  end
end