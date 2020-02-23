# frozen_string_literal: true

require 'serialport'
require 'logger'
require 'timeout'

class SenseairS8
  STARTING_BYTE         = 0xFE

  COMMANDS = {
    get_co2_concentration:  0x04
  }.freeze

  DEFAULT_IO = '/dev/serial0'
  READ_TIMEOUT_SECONDS = 1

  class GenericException < RuntimeError; end
  class InvalidPacketException < GenericException; end

  attr_reader :io, :logger

  def initialize(io: DEFAULT_IO, logger: Logger.new(STDOUT))
    @io = io.is_a?(String) ? build_serial_port(io) : io
    @logger = logger
  end

  def close
    io.close
  end

  def data
    sensor_send
    packet = sensor_read

    {
      concentration: (packet[3] * 256) + packet[4]
    }
  end

  private

  def sensor_send
    packet = [STARTING_BYTE, 0x44, 0, 8, 2, 0x9F, 0x25]

    logger.debug "Sending: #{packet}"
    io.flush
    io.write packet.pack('C*')
  end

  def sensor_read(bytes_count = 7)
    logger.debug "Reading #{bytes_count} bytes..."
    raw_packet = Timeout.timeout(READ_TIMEOUT_SECONDS) { io.read(bytes_count) }
    raise InvalidPacketException, 'empty response' if raw_packet.nil?

    unpacked = raw_packet.unpack('C*')
    logger.debug "Response: #{unpacked}, size: #{unpacked.size}"
    return unpacked #if unpacked[8] == calculate_checksum(unpacked)

    logger.fatal "Checksum mismatch, should be #{calculate_checksum(unpacked)}"
    raise InvalidPacketException, 'packet checksum is invalid'
  end

  def build_serial_port(io)
    SerialPort.new(io, 9600, 8, 1, 0).tap do |port|
      port.flow_control = SerialPort::NONE
      port.set_encoding(Encoding::BINARY)
    end
  end
end
