# frozen_string_literal: true

module MedianFilter
  extend self

  FILTER_PERIOD_SECONDS = 30
  COLLECTION_DELAY_SECONDS = 3

  def collect_filtered(period: FILTER_PERIOD_SECONDS, delay: COLLECTION_DELAY_SECONDS, logger: Logger.new(STDOUT))
    data = {}
    n = 0

    begin
      Timeout.timeout(period) do
        loop do
          logger.debug "Collecting #{n += 1} sample"
          result = yield
          logger.debug "Got #{result}"

          result.each do |field, value|
            (data[field] ||= []) << value
          end

          logger.debug "Sleeping #{delay} seconds"
          sleep(delay)
        end
      end
    rescue Timeout::Error
      logger.debug "Collection period of #{period} seconds finished"
    end

    data.keys.each_with_object({}) do |field, memo|
      logger.debug "Got #{data[field].size} samples for #{field}: #{data[field].sort}"

      # Let's keep first value as unfiltered
      memo[field.to_s] = data[field].first

      memo["#{field}_filtered_median"] = median(data[field])
      memo["#{field}_filtered_avg"] = data[field].sum / data[field].size.to_f
    end
  end

  def median(array)
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end
