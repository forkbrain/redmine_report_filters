class ProjectReportsController < ApplicationController
  unloadable
  menu_item :issues
  before_filter :find_project, :find_issue_statuses
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog

  def average_age_report
    settings = Setting.where(:name => 'plugin_redmine_report_filters').first
    date_format = Setting.where(:name => 'date_format').first
    date_format = date_format.value if date_format.present?
    settings = settings.value["settings_closed_statuses"].to_a if settings.present?
    if settings.nil? || settings.empty?
      @not_configure = 1
    else
      retrieve_query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      @query.sort_criteria = sort_criteria.to_a
      @issue_count = @query.issue_count
      @offset = 0
      puts @issues
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)

      @period = params[:period_report]
      @days_previously = params[:days_previously]
      @chart = ""
      @days = 0
      session[:period_report] = "daily"
      session[:period_report] = @period if @period.present?
      session[:days_previously] = 0
      session[:days_previously] = @days_previously if @days_previously.present?
      if @days_previously.present? && @period.present? && @days_previously.to_i > 0
        i = @days_previously.to_i
        week = (i.days.ago).strftime("%W").to_i
        month = (i.days.ago).strftime("%m").to_i
        @table_results = []
        n = 0
        @days_previously.to_i.times do
          n += 1
          @res = @issues.select{|x| x.created_on <= i.days.ago && !settings.include?(x.status_id.to_s)}
          @days = 0
          @res.each do |j|
            @days += (DateTime.now - j.created_on.to_datetime).to_i
          end
          if @res.count > 0
            if @period.present? && @period == "weekly" && week < i.days.ago.strftime("%W").to_i
              @chart += "{ \"date\": \"#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}\", \"days\": \"#{(@days/@res.count).to_s}\"}"
              @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
              week = i.days.ago.strftime("%W").to_i
              @table_results << TableResult.new("#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}", @res.count, @days, @days/@res.count)
              n = 0
            end
            if @period.present? && @period == "monthly" && month < i.days.ago.strftime("%m").to_i
              @chart += "{ \"date\": \"#{i.days.ago.strftime("%b %Y")}\", \"days\": \"#{(@days/@res.count).to_s}\"}"
              @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
              month = i.days.ago.strftime("%m").to_i
              @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @res.count, @days, @days/@res.count)
            end
            if @period.present? && @period == "daily"
              @chart += "{ \"date\": \"#{i.days.ago.strftime(date_format.to_s)}\", \"days\": \"#{(@days/@res.count).to_s}\"}"
              @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
              week = i.days.ago.strftime("%W").to_i
              @table_results << TableResult.new(i.days.ago.strftime(date_format.to_s), @res.count, @days, @days/@res.count)
            end
          end
          i -= 1
        end
      end
    end
  end

  def created_vs_resolved_report

  end

  private

  def find_issue_statuses
    @statuses = IssueStatus.sorted.all
  end
end