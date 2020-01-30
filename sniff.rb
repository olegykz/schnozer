# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'dotenv/load'

Bundler.require(:default)

require_relative 'sensors/mh_z19b'
require_relative 'sensors/bme280'
require_relative 'concerns/median_filter'

Dotenv.require_keys('INFLUX_URL')

LOGFILES_COUNT = 5
LOGFILE_SIZE = 1_024_000

mh_z19b_data = {}
bme280_data = {}

logger = Logger.new(ENV.fetch('LOG_FILE', STDOUT), LOGFILES_COUNT, LOGFILE_SIZE)
logger.level = ENV.fetch('LOG_LEVEL', 'debug')

threads = []
threads << Thread.new(mh_z19b_data) do |result|
  begin
    mh_z19b = MhZ19B.new(logger: logger)
    result.merge!(
      series: 'mh_z19b',
      values: mh_z19b.data
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

influxdb =
  InfluxDB::Client.new
    url: ENV['INFLUXDB_SERVER'],
    user: ENV['INFLUXDB_USER'],
    password: ENV['INFLUXDB_PASSWORD'],
    verify_ssl: false

p influxdb.write_points([bme280_data, mh_z19b_data]).inspect
binding.pry if ENV['INTERACTIVE'] == 'pry'
