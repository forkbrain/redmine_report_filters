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
  include ProjectReportsHelper
  include ReportsHelper

  def average_age_report
    set_settings
    if @plugin_settings.nil? || @plugin_settings.empty?
      @not_configure = 1
    else
      query_initialize
      variables_init
      if @days_previously.present? && @period.present? && @days_previously.to_i > 0
        i = @days_previously.to_i
        week = (i.days.ago).strftime("%W").to_i
        month = (i.days.ago).strftime("%m").to_i
        n = 0
        set_variables
        @days_previously.to_i.times do
          @res = @issues.select{|x| x.created_on <= i.days.ago && !@plugin_settings.include?(x.status_id.to_s)}
          n += 1
          @days = 0
          @res.uniq.each do |j|
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
                @chart += "{ \"date\": \"#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}\", \"days\": \"#{(@week_days/@weeks_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}", @weeks_count, @week_days, @week_days/@weeks_count)
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
                @chart += "{ \"date\": \"#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}\", \"days\": \"#{(@week_days/@weeks_count).to_s}\"}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}", @weeks_count, @week_days, @week_days/@weeks_count)
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
              @chart += "{ \"date\": \"#{i.days.ago.strftime(@date_format.to_s)}\", \"days\": \"#{(@days/@res.count).to_s}\"}"
              @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
              week = i.days.ago.strftime("%W").to_i
              @table_results << TableResult.new(i.days.ago.strftime(@date_format.to_s), @res.count, @days, @days/@res.count)
            end
          end
          i -= 1
        end
      end
    end
  end

  def created_vs_resolved_report
    set_settings
    if @plugin_settings.nil? || @plugin_settings.empty?
      @not_configure = 1
    else
      query_initialize
      variables_init
      if @days_previously.present? && @period.present? && @days_previously.to_i > 0
        i = @days_previously.to_i
        week = (i.days.ago).strftime("%W").to_i
        month = (i.days.ago).strftime("%m").to_i
        n = 0
        set_variables
        @days_previously.to_i.times do
          @res = @issues.select{|x| x.created_on.to_date == i.days.ago.to_date}
          @closed = @issues.select{|x| x.closed_on.present? && x.closed_on.to_date == i.days.ago.to_date}
          n += 1
          @days = 0
          @days_closed = 0
          @res.uniq.each do |j|
            @days += 1
            @weeks_all_days << j
            @month_all_days << j
          end
          @closed.uniq.each do |j|
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
                @chart += "{ 'date': '#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}', 'resolved': '#{@week_days_closed}', 'created': '#{@weeks_days}',  'createdColor':'#{@colors[0]}', 'resolvedColor':'#{@colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}", @weeks_days, @week_days_closed, @week_days)
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
                @chart += "{ 'date': '#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}',  'resolved': '#{@week_days_closed}', 'created': '#{@weeks_days}', 'createdColor':'#{@colors[0]}', 'resolvedColor':'#{@colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                week = i.days.ago.strftime("%W").to_i
                @table_results << TableResult.new("#{(n + i).days.ago.strftime(@date_format.to_s)} - #{i.days.ago.strftime(@date_format.to_s)}", @weeks_days, @week_days_closed, @week_days)
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
                @chart += "{ 'date': '#{i.days.ago.strftime("%b %Y")}', 'resolved': '#{@month_days_closed}', 'created': '#{@month_days}', 'createdColor':'#{@colors[0]}', 'resolvedColor':'#{@colors[1]}'}"
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
                @chart += "{ 'date': '#{i.days.ago.strftime("%b %Y")}', 'resolved': '#{@month_days_closed}', 'created': '#{@month_days}', 'createdColor':'#{@colors[0]}', 'resolvedColor':'#{@colors[1]}'}"
                @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
                @table_results << TableResult.new(i.days.ago.strftime("%b %Y"), @month_days, @month_days_closed, @month_days)
                @month_all_days = []
                @month_all_days_closed = []
              end
            end
          end

          if @period.present? && @period == "daily"
            @chart += "{ 'date': '#{i.days.ago.strftime(@date_format.to_s)}', 'resolved': '#{(@days_closed + @resolved).to_s}',  'created': '#{(@days + @created).to_s}', 'createdColor':'#{@colors[0]}', 'resolvedColor':'#{@colors[1]}'}"
            @chart += "," if (@days_previously.to_i - i) < @days_previously.to_i - 1
            week = i.days.ago.strftime("%W").to_i
            @table_results << TableResult.new(i.days.ago.strftime(@date_format.to_s), @days, @days_closed, @res.count)
            @created += @days
            @resolved += @days_closed
          end

          i -= 1
        end
      end
    end
  end

  def pie_chart_report
    set_settings
    if @plugin_settings.nil? || @plugin_settings.empty?
      @not_configure = 1
    else
      query_initialize
      variables_init
      set_variables
      @custom_fields = CustomField.where( :field_format => 'list' )
      result = nil
      @issues.each_with_index do |t, i|
        result = "(" if result.nil?
        result += "#{Issue.table_name}.id=#{t.id}"
        result += " OR " if i < @issues.count - 1
        result += ")" if i == @issues.count - 1
      end
      if session[:cb_dates].to_s == "checked"
        date_to = session[:date_to]
        date_from = session[:date_from]
      end
      @issue_count = @query.issue_count
      @query_result_issue = result
      if params[:cb_dates].present? && params[:cb_dates].to_s.to_bool
        date_from = params[:date_from]
        date_to = params[:date_to]
        session[:cb_dates] = "checked"
      else
        session[:cb_dates] = ""
        date_from = date_to = nil
      end
      if params[:pie_type].present? && params[:pie_type].index('custom_field_')
        if params[:detail].split('_')[2].to_i > 0
          @custom_field = CustomField.where(:id=> params[:detail].split('_')[2], :field_format => 'list' ).first
          if @custom_field.present?
            @field = params[:detail]
            @rows = @custom_field.possible_values
            @report_title = @custom_field.name
            @query_result_issue = result
          end
        end
      elsif params[:pie_type].present?
        session[:pie_type] = params[:pie_type]
        case params[:pie_type]
          when "tracker_id"
            @field = "tracker_id"
            @rows = @project.trackers
            @data = Issue.by_tracker(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_tracker)
            puts @data
          when "fixed_version_id"
            @field = "fixed_version_id"
            @rows = @project.shared_versions.sort
            @data = Issue.by_version(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_version)
          when "priority_id"
            @field = "priority_id"
            @rows = IssuePriority.all.reverse
            @data = Issue.by_priority(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_priority)
          when "category_id"
            @field = "category_id"
            @rows = @project.issue_categories
            @data = Issue.by_category(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_category)
          when "assigned_to_id"
            @field = "assigned_to_id"
            @rows = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
            @data = Issue.by_assigned_to(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_assigned_to)
          when "author_id"
            @field = "author_id"
            @rows = @project.users.sort
            @data = Issue.by_author(@project, date_from, date_to, result, @issue_count)
            @report_title = l(:field_author)
          when "project_id"
            @field = "project_id"
            @rows = @project.descendants.visible
            @data = Issue.by_subproject(@project) || []
            @report_title = l(:field_subproject)
        end
      end
      if @rows.present?
        count = 0
        @rows.each_with_index do |t, i|
          total = (aggregate @data, @field => t.id).to_i
          count += total
          @chart += "{ 'field': '#{t.name}', 'count': '#{total}' }"
          @chart += "," if i < @rows.count - 1
          @table_results << TableResult.new(t, total, "#{(total * 100) / @project.issues.count} %", t.name)
        end
        if count < @project.issues.count
          total = @project.issues.count - count
          @chart += ",{ 'field': '#{t(:not_assigned)}', 'count': '#{total}' }"
          @table_results << TableResult.new(nil, total, "#{(total * 100) / @project.issues.count} %", t(:not_assigned))
        end
      end
    end
  end

  private

  def find_issue_statuses
    @statuses = IssueStatus.sorted.all
  end
end