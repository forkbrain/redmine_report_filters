require 'active_support/core_ext'
class ProjectReportsController < ApplicationController
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
        @weeks_all_days = Array.new
        @month_all_days = Array.new
        @week_days = 0
        @month_days = 0
        @days_previously.to_i.times do
          @res = @issues.select{|x| x.created_on <= i.days.ago && !settings.include?(x.status_id.to_s)}
          n += 1
          @days = 0
          @res.uniq.each do |j|
            puts i
            @days += (Date.today - j.created_on.to_date).to_i
            @weeks_all_days << j
            @month_all_days << j
          end

          if @period.present? && @period == "weekly"
            if  i.days.ago.end_of_week.to_date == i.days.ago.to_date
              if @weeks_all_days.uniq.count > 0
                @weeks_all_days.uniq.each do |j|
                  @week_days += (Date.today - j.created_on.to_date).to_i
                end
                n -= 1
                @weeks_count = @weeks_all_days.uniq.count
                @chart += "{ \"date\": \"#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}\", \"days\": \"#{(@week_days/@weeks_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}", @weeks_count, @week_days, @week_days/@weeks_count)
                @weeks_all_days = []
              end
              n = 0
              @week_days = 0
            end
            if i == 1 && i.days.ago.end_of_week.to_date != i.days.ago.to_date
              if @weeks_all_days.uniq.count > 0
                @weeks_all_days.uniq.each do |j|
                  @week_days += (Date.today - j.created_on.to_date).to_i
                end
                @weeks_count = @weeks_all_days.uniq.count
                @chart += "{ \"date\": \"#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}\", \"days\": \"#{(@week_days/@weeks_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}", @weeks_count, @week_days, @week_days/@weeks_count)
                @weeks_all_days = []
              end
              n = 0
              @week_days = 0
            end

          end
          if @period.present? && @period == "monthly"
            if i.days.ago.end_of_month.to_date == i.days.ago.to_date
              if @month_all_days.uniq.count > 0
                @month_all_days.uniq.each do |j|
                  @month_days += (Date.today - j.created_on.to_date).to_i
                end
                @month_count = @month_all_days.uniq.count
                @chart += "{ \"date\": \"#{i.days.ago.strftime("%b %Y")}\", \"days\": \"#{(@month_days/@month_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @month_count, @month_days, @month_days/@month_count)
                @month_days = 0
              end
            end
            if  i == 1 && i.days.ago.end_of_month.to_date != i.days.ago.to_date
              if @month_all_days.uniq.count > 0
                @month_all_days.uniq.each do |j|
                  @month_days += (Date.today - j.created_on.to_date).to_i
                end
                @month_count = @month_all_days.uniq.count
                @chart += "{ \"date\": \"#{i.days.ago.strftime("%b %Y")}\", \"days\": \"#{(@month_days/@month_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @month_count, @month_days, @month_days/@month_count)
                @month_days = 0
              end
            end
          end
          if @res.count > 0
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
    settings = Setting.where(:name => 'plugin_redmine_report_filters').first
    date_format = Setting.where(:name => 'date_format').first
    date_format = date_format.value if date_format.present?
    settings = settings.value["settings_closed_statuses"].to_a if settings.present?
    colors = ['#FF3030', '#009900']
    if settings.nil? || settings.empty?
      @not_configure = 1
    else
      retrieve_query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      @query.sort_criteria = sort_criteria.to_a
      @issue_count = @query.issue_count
      @offset = 0
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)

      @period = params[:period_report]
      @days_previously = params[:days_previously]
      @chart = ""
      @days = 0
      @created = 0
      @resolved = 0
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
        @weeks_all_days = Array.new
        @month_all_days = Array.new
        @weeks_all_days_closed = Array.new
        @month_all_days_closed = Array.new
        @week_days = 0
        @month_days = 0
        @week_days_closed = 0
        @month_days_closed = 0
        @days_previously.to_i.times do
          @res = @issues.select{|x| x.created_on.to_date == i.days.ago.to_date}
          @closed = @issues.select{|x| x.closed_on.present? && x.closed_on.to_date == i.days.ago.to_date}
          n += 1
          @days = 0
          @days_closed = 0
          @res.uniq.each do |j|
            puts i
            @days += 1
            @weeks_all_days << j
            @month_all_days << j
          end
          @closed.uniq.each do |j|
            puts i
            @days_closed += 1
            @weeks_all_days_closed << j
            @month_all_days_closed << j
          end

          if @period.present? && @period == "weekly"
            if  i.days.ago.end_of_week.to_date == i.days.ago.to_date
              if @weeks_all_days.uniq.count > 0
                n -= 1
                @weeks_days = @weeks_all_days.uniq.count
                @week_days_closed = @weeks_all_days_closed.uniq.count
                @chart += "{ 'date': '#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}', 'resolved': '#{@week_days_closed}', 'created': '#{@weeks_days}',  'createdColor':'#{colors[0]}', 'resolvedColor':'#{colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}", @weeks_days, @week_days_closed, @week_days)
                @weeks_all_days = []
                @weeks_all_days_closed = []
              end
              n = 0
              @week_days = 0
              @week_days_closed = 0
            end
            if i == 1 && i.days.ago.end_of_week.to_date != i.days.ago.to_date
              if @weeks_all_days.uniq.count > 0
                @weeks_days = @weeks_all_days.uniq.count
                @week_days_closed = @weeks_all_days_closed.uniq.count
                @chart += "{ 'date': '#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}',  'resolved': '#{@week_days_closed}', 'created': '#{@weeks_days}', 'createdColor':'#{colors[0]}', 'resolvedColor':'#{colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(date_format.to_s)} - #{i.days.ago.strftime(date_format.to_s)}", @weeks_days, @week_days_closed, @week_days)
                @weeks_all_days = []
                @weeks_all_days_closed = []
              end
              n = 0
              @week_days = 0
              @week_days_closed = 0
            end

          end
          if @period.present? && @period == "monthly"
            if i.days.ago.end_of_month.to_date == i.days.ago.to_date
              if @month_all_days.uniq.count > 0
                @month_days = @month_all_days.uniq.count
                @month_days_closed = @month_all_days_closed.uniq.count
                @chart += "{ 'date': '#{i.days.ago.strftime("%b %Y")}', 'resolved': '#{@month_days_closed}', 'created': '#{@month_days}', 'createdColor':'#{colors[0]}', 'resolvedColor':'#{colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @month_days, @month_days_closed, @month_days)
                @month_all_days = []
                @month_all_days_closed = []
              end
            end
            if  i == 1 && i.days.ago.end_of_month.to_date != i.days.ago.to_date
              if @month_all_days.uniq.count > 0
                @month_days = @month_all_days.uniq.count
                @month_days_closed = @month_all_days_closed.uniq.count
                @chart += "{ 'date': '#{i.days.ago.strftime("%b %Y")}', 'resolved': '#{@month_days_closed}', 'created': '#{@month_days}', 'createdColor':'#{colors[0]}', 'resolvedColor':'#{colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @month_days, @month_days_closed, @month_days)
                @month_all_days = []
                @month_all_days_closed = []
              end
            end
          end
          
          if @period.present? && @period == "daily"
            @chart += "{ 'date': '#{i.days.ago.strftime(date_format.to_s)}', 'resolved': '#{(@days_closed + @resolved).to_s}',  'created': '#{(@days + @created).to_s}', 'createdColor':'#{colors[0]}', 'resolvedColor':'#{colors[1]}'}"
            @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
            week = i.days.ago.strftime("%W").to_i
            @table_results << TableResult.new(i.days.ago.strftime(date_format.to_s), @days, @days_closed, @res.count)
            @created += @days
            @resolved += @days_closed
          end

          i -= 1
        end
      end
    end
  end

  private

  def find_issue_statuses
    @statuses = IssueStatus.sorted.all
  end
end