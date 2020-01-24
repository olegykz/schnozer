# frozen_string_literal: true

require 'serialport'
require 'logger'
require 'timeout'

class MhZ19B
  STARTING_BYTE = 0xFF
  CMD_GAS_CONCENTRATION = 0x86
  CMD_ABC_CHECK = 0x79
  DEFAULT_IO = '/dev/serial0'
  READ_TIMEOUT_SECONDS = 1

  class GenericException < RuntimeError; end
  class InvalidPacketException < GenericException; end

  attr_reader :io, :logger

  def initialize(io: DEFAULT_IO, sensor_id: 0x01, logger: Logger.new(STDOUT))
    @io = io.is_a?(String) ? build_serial_port(io) : io
    @logger = logger
    @sensor_id = sensor_id

    disable_abc
  end

  def close
    io.close
  end

  def data
    sensor_send(command: CMD_GAS_CONCENTRATION)
    packet = Timeout.timeout(READ_TIMEOUT_SECONDS) { sensor_read }

    {
      concentration: (packet[2] << 8) | packet[3],
      temperature: (packet[4] - 40),
      status: packet[5]
    }
  end

  private

  def disable_abc
    # parameter: 0xA0 to enable ABC
    sensor_send(command: CMD_ABC_CHECK, parameter: 0)

    sleep(0.1)
    io.flush
  end

  def sensor_send(command:, parameter: 0)
    packet = [STARTING_BYTE, @sensor_id, command, parameter, 0, 0, 0, 0, 0]
    packet[-1] = calculate_checksum(packet)

    logger.debug "Sending: #{packet}"
    io.flush
    io.write packet.pack('C*')
  end

  def sensor_read
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
      sum = (sum + packet[i]) & 0xFF
    end

    0xFF - sum + 1
  end
end
