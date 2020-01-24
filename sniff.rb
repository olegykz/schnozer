# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'dotenv/load'
require 'influxdb2/client'

require_relative 'sensors/mh_z19b'
require_relative 'sensors/bme280'
require_relative 'concerns/median_filter'

Dotenv.require_keys('INFLUX_HOST', 'INFLUX_ORGANIZATION', 'INFLUX_BUCKET', 'INFLUX_TOKEN')

LOGFILES_COUNT = 5
LOGFILE_SIZE = 1_024_000

mh_z19b_data = nil

logger = Logger.new(ENV.fetch('LOG_FILE', STDOUT), LOGFILES_COUNT, LOGFILE_SIZE)
logger.level = ENV.fetch('LOG_LEVEL', 'debug')

begin
  mh_z19b = MhZ19B.new(logger: logger)
  mh_z19b_data = { name: 'mh_z19b', fields: MedianFilter.collect_filtered { mh_z19b.data } }

  logger.debug("MH-Z19B data: #{mh_z19b_data}")
ensure
  mh_z19b&.close
end

bme280 = Bme280.new(logger: logger)
bme280_data = { name: 'bme280', fields: MedianFilter.collect_filtered { bme280.data } }
logger.debug("BME280 data: #{bme280_data}")

client = InfluxDB2::Client.new(
  ENV['INFLUX_HOST'],
  ENV['INFLUX_TOKEN'],
  org: ENV['INFLUX_ORGANIZATION'],
  bucket: ENV['INFLUX_BUCKET'],
  precision: InfluxDB2::WritePrecision::SECOND
)

write_api = client.create_write_api
logger.debug 'Sending data to Influx...'
# write_api.write(data: [bme280_data, mh_z19b_data]).tap do |result|
#   logger.debug "Result: #{result}"
# end
