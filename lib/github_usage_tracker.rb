require 'uri'

class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def self.configured?
    @configured ||= Settings.influxdb_credentials.to_hash.delete_blanks.present?
  end

  def self.influxdb
    @influx ||= InfluxDB::Client.new(Settings.influxdb_credentials.database,
                                     :username => Settings.influxdb_credentials.username,
                                     :password => Settings.influxdb_credentials.password,
                                     :time_precision => 'ms')
  end

  def record_datapoint(requests_remaining:, uri:, timestamp: Time.now)
    return unless configured?

    request_uri = URI.parse(uri).path.chomp("/")

    values = { :tags      => { :bot_version        => MiqBot.version },
               :values    => { :requests_remaining => requests_remaining.to_i, :uri => request_uri },
               :timestamp => (timestamp.to_f * 1000).to_i } # ms precision

    worker = worker_from_backtrace
    values[:tags].merge!(:worker => worker) if worker

    influxdb.write_point('github_api_request', values)
  rescue => e
    Rails.logger.info("#{e.class}: #{e.message}")
  end

  private

  delegate :influxdb, :configured?, :to => self

  def worker_from_backtrace
    caller.each do |l|
      match = /(?:app\/workers\/)(?:\w+\/)*?(\w+)(?:\.rb\:\d+)/.match(l)
      return match[1] if match && match[1].exclude?("_mixin")
    end
    nil
  end
end
