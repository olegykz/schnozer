#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'json'

Bundler.require(:default)

require_relative 'sensors/mh_z19b'
require_relative 'sensors/bme280'

LOGFILES_COUNT = 5
LOGFILE_SIZE = 1_024_000

logger = Logger.new(ENV.fetch('LOG_FILE', STDOUT), LOGFILES_COUNT, LOGFILE_SIZE)
logger.level = ENV.fetch('LOG_LEVEL', 'debug')


wifi_ssid = `/sbin/iwgetid -r`&.chomp
logger.debug "WiFi SSID: #{wifi_ssid}"

base_data = { tags: { wifi_ssid: wifi_ssid } }
mh_z19b_data = base_data.dup
bme280_data = base_data.dup

threads = []
threads << Thread.new(mh_z19b_data) do |result|
  begin
    mh_z19b = MhZ19B.new(logger: logger)
    result.merge!(
      series: 'mh_z19b',
      values: mh_z19b.data,
    )

    logger.info("MH-Z19B data: #{mh_z19b_data}")
  ensure
    mh_z19b&.close
  end
end

threads << Thread.new(bme280_data) do |result|
  bme280 = Bme280.new(logger: logger)
  result.merge!(
    series: 'bme280',
    values: bme280.data
  )

  logger.info("BME280 data: #{bme280_data}")
end

threads.map(&:join)

pipe_name = 'sniff.json'
File.mkfifo(pipe_name) unless File.exists?(pipe_name)
File.write(pipe_name, [bme280_data, mh_z19b_data].to_json + "\n", { mode: 'w+' })

binding.pry if ENV['INTERACTIVE'] == 'pry'

telegraf = Telegraf::Agent.new 'udp://localhost:8094'
telegraf.write([bme280_data, mh_z19b_data])
