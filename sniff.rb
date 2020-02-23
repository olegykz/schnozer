#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require_relative 'sensors/mh_z19b'
require_relative 'sensors/bme280'
require_relative 'sensors/senseair_s8'
require_relative 'concerns/median_filter'

LOGFILES_COUNT = 5
LOGFILE_SIZE = 1_024_000

logger = Logger.new(ENV.fetch('LOG_FILE', STDOUT), LOGFILES_COUNT, LOGFILE_SIZE)
logger.level = ENV.fetch('LOG_LEVEL', 'debug')


# wifi_ssid = `iwgetid -r`&.chomp
# if wifi_ssid.empty?
#   logger.fatal "No WiFi detected! iwgetid output: #{`iwgetid`}"
#   exit 1
# end

base_data = { tags: { wifi_ssid: 'oleole' } }
senseair_s8_data = base_data.dup
bme280_data = base_data.dup

threads = []
threads << Thread.new(senseair_s8_data) do |result|
  begin
    senseair_s8 = SenseairS8.new(logger: logger)
    result.merge!(
      series: 'senseair_s8',
      values: senseair_s8.data,
    )

    logger.info("Senseair S8 data: #{senseair_s8_data}")
  ensure
    senseair_s8&.close
  end
end

threads << Thread.new(bme280_data) do |result|
  Thread.current.exit
  bme280 = Bme280.new(logger: logger)
  result.merge!(
    series: 'bme280',
    values: bme280.data
  )

  logger.info("BME280 data: #{bme280_data}")
end

threads.map(&:join)

binding.pry if ENV['INTERACTIVE'] == 'pry'

telegraf = Telegraf::Agent.new 'udp://localhost:8094'
telegraf.write([senseair_s8_data])
