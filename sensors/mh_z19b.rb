# frozen_string_literal: true

require 'serialport'
require 'logger'
require 'timeout'

class MhZ19B
  STARTING_BYTE         = 0xFF

  COMMANDS = {
    get_co2_concentration:  0x86,
    set_abc_mode:           0x79,
    get_abc_mode:           0x7D,
    mcu_reset:              0x8D,
    zero_point_calibration: 0x87,
    range_change:           0x99
  }.freeze

  DEFAULT_IO = '/dev/serial0'
  READ_TIMEOUT_SECONDS = 1

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
    check_abc

    sensor_send(command: COMMANDS[:get_co2_concentration])
    packet = sensor_read

    {
      concentration: (packet[2] << 8) | packet[3],
      temperature: (packet[4] - 40),
      status: packet[5]
    }
  end

  private

  def check_abc
    return true if @abc_disabled

    disable_abc if get_abc_settings[:abc_mode]
    @abc_disabled = !get_abc_settings[:abc_mode]
  end

  def zero_point_calibration
    sensor_send(command: COMMANDS[:zero_point_calibration])
  end

  def get_abc_settings
    sensor_send(command: COMMANDS[:get_abc_settings])
    packet = sensor_read

    { abc_mode: sensor_read[7] == 1}
  end

  def enable_abc
    sensor_send(command: COMMANDS[:set_abc_mode], parameter: 0xA0)
    sensor_read
  end

  def disable_abc
    sensor_send(command: COMMANDS[:set_abc_mode])
    sensor_read
  end

  def reset_mcu
    sensor_send(command: COMMANDS[:mcu_reset])
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
    raw_packet = Timeout.timeout(READ_TIMEOUT_SECONDS) { io.read(9) }
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
