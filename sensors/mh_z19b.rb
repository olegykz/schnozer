# frozen_string_literal: true

require 'serialport'
require 'logger'

class MhZ19B
  STARTING_BYTE = 0xff
  CMD_GAS_CONCENTRATION = 0x86
  DEFAULT_IO = '/dev/serial0'

  class GenericException < RuntimeError; end
  class InvalidPacketException < GenericException; end

  attr_reader :io, :logger

  def initialize(io: DEFAULT_IO, sensor_id: 0x01, logger: Logger.new(STDOUT))
    @io = io.is_a?(String) ? build_serial_port(io) : io
    @logger = logger
    @sensor_id = sensor_id
  end

  def close
    io.close
  end

  def data
    send_read_command
    packet = read_response

    {
      name: 'mh_z19b',
      fields: {
        concentration: (packet[2] << 8) | packet[3],
        temperature: (packet[4] - 40),
        status: packet[5]
      }
    }
  end

  private

  def send_read_command
    packet = [STARTING_BYTE, @sensor_id, CMD_GAS_CONCENTRATION, 0, 0, 0, 0, 0, 0]
    packet[-1] = calculate_checksum(packet)

    logger.debug "Sending: #{packet}"
    io.flush
    io.write packet.pack('C*')
  end

  def send_reset_command(command_number = 0x89)
    packet = [STARTING_BYTE, @sensor_id, command_number, 0, 0, 0, 0, 0, 0]
    packet[-1] = calculate_checksum(packet)

    logger.debug "Sending: #{packet}"
    io.flush
    io.write packet.pack('C*')
  end

  def read_response
    logger.debug 'Reading 9 bytes...'
    raw_packet = io.read(9)
    raise InvalidPacketException, 'empty response' if raw_packet.nil?

    unpacked = raw_packet.unpack('C*')
    logger.debug "Response: #{unpacked}, size: #{unpacked.size}"
    return unpacked if unpacked[8] == calculate_checksum(unpacked)

    logger.fatal "Checksum mismatch, should be #{calculate_checksum(unpacked)}"
    raise InvalidPacketException, 'packet checksum is invalid'
  end

  def build_serial_port(io)
    SerialPort.new(io, 9600, 8, 1, 0).tap do |port|
      port.flow_control = SerialPort::NONE
      port.set_encoding(Encoding::BINARY)
    end
  end

  def calculate_checksum(packet)
    raise InvalidPacketException, 'invalid packet size' unless packet.size == 9

    sum = 0
    (1...8).each do |i|
      sum = (sum + packet[i]) & 0xff
    end

    0xff - sum + 1
  end
end
