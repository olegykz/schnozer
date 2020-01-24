require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'dotenv/load'
require 'influxdb2/client'

require_relative 'mh_z19b.rb'
require_relative 'bme280.rb'

mh_z19b_data = nil
bme280_data = nil

begin
  mh_z19b = MhZ19B.new
  mh_z19b_data = mh_z19b.data
  p mh_z19b_data
ensure
  mh_z19b&.close
end

bme280_data = Bme280.new.data
p bme280_data


client = InfluxDB2::Client.new(
  ENV['INFLUX_HOST'], 
  ENV['INFLUX_TOKEN'],
  org: ENV['INFLUX_ORGANIZATION'],
  bucket: ENV['INFLUX_BUCKET'], 
  precision: InfluxDB2::WritePrecision::SECOND
)

write_api = client.create_write_api
write_api.write(data: [bme280_data, mh_z19b_data]) 
# binding.pry

