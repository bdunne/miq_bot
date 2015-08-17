class PullRequestMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      report = MemoryProfiler.report do
        CommitMonitorRepo.includes(:branches).each do |repo|
          next unless repo.upstream_user
          RepoProcessor.process(repo)
        end
      end
      logger.warn("========== COMMIT MONITOR START ==========")
      logger.warn(report.pretty_print)
      logger.warn("========== COMMIT MONITOR END ==========")
    end
  end
end
