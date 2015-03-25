# encoding: utf-8
Redmine::Plugin.register :redmine_report_filters do
  name 'Redmine Reports Filters plugin'
  author 'Forkbrain ltd'
  description 'The plugin adds the ability to filter tasks in the reports.'
  version '1.2.4'
  url 'http://redmine.forkbrain.com'
  author_url 'http://redmine.forkbrain.com'

  module ReportsControllerPatch
    def self.included(base)
      base.class_eval do
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

        def issue_report
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
          result = nil
          @issues.each_with_index do |t, i|
            result = "(" if result.nil?
            result += "#{Issue.table_name}.id=#{t.id}"
            result += " OR " if i < @issues.count - 1
            result += ")" if i == @issues.count - 1
          end
          @query_result_issue = result
          session[:date_from] = params[:date_from] if params[:date_from].present?
          session[:date_to] = params[:date_to] if params[:date_to].present?
          @trackers = @project.trackers
          @versions = @project.shared_versions.sort
          @priorities = IssuePriority.all.reverse
          @categories = @project.issue_categories
          @assignees = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
          @authors = @project.users.sort
          @subprojects = @project.descendants.visible
          if params[:cb_dates].present? && params[:cb_dates].to_s.to_bool
            date_from = params[:date_from]
            date_to = params[:date_to]
            session[:cb_dates] = "checked"
          else
            session[:cb_dates] = ""
            date_from = date_to = nil
          end
          @custom_fields = @project.all_issue_custom_fields.select{|x| x.field_format == 'list'}
          @issues_by_tracker = Issue.by_tracker(@project, date_from, date_to, result, @issue_count)
          @issues_by_version = Issue.by_version(@project, date_from, date_to, result, @issue_count)
          @issues_by_priority = Issue.by_priority(@project, date_from, date_to, result, @issue_count)
          @issues_by_category = Issue.by_category(@project, date_from, date_to, result, @issue_count)
          @issues_by_assigned_to = Issue.by_assigned_to(@project, date_from, date_to, result, @issue_count)
          @issues_by_author = Issue.by_author(@project, date_from, date_to, result, @issue_count)
          @issues_by_subproject = Issue.by_subproject(@project) || []
          render :template => "reports/issue_report"
        end
        def issue_report_details
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
          if params[:detail].index('custom_field_')
            if params[:detail].split('_')[2].to_i > 0
              @custom_field = CustomField.where(:id=> params[:detail].split('_')[2], :field_format => 'list' ).first
              if @custom_field.present?
                @field = params[:detail]
                @rows = @custom_field.possible_values
                @report_title = @custom_field.name
                @query_result_issue = result
              end
            end
          else
            case params[:detail]
              when "tracker"
                @field = "tracker_id"
                @rows = @project.trackers
                @data = Issue.by_tracker(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_tracker)
              when "version"
                @field = "fixed_version_id"
                @rows = @project.shared_versions.sort
                @data = Issue.by_version(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_version)
              when "priority"
                @field = "priority_id"
                @rows = IssuePriority.all.reverse
                @data = Issue.by_priority(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_priority)
              when "category"
                @field = "category_id"
                @rows = @project.issue_categories
                @data = Issue.by_category(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_category)
              when "assigned_to"
                @field = "assigned_to_id"
                @rows = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
                @data = Issue.by_assigned_to(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_assigned_to)
              when "author"
                @field = "author_id"
                @rows = @project.users.sort
                @data = Issue.by_author(@project, date_from, date_to, result, @issue_count)
                @report_title = l(:field_author)
              when "subproject"
                @field = "project_id"
                @rows = @project.descendants.visible
                @data = Issue.by_subproject(@project) || []
                @report_title = l(:field_subproject)
            end
          end

          respond_to do |format|
            if @field
              format.html {}
            else
              format.html { redirect_to :action => 'issue_report', :id => @project }
            end
          end
        end
      end
    end
  end
  module IssuePatch
    def self.included(base)
      base.class_eval do
        # Extracted from the ReportsController.
        def self.by_tracker(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'tracker_id',
                             :joins => Tracker.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count
          )
        end

        def self.by_version(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'fixed_version_id',
                             :joins => Version.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count)
        end

        def self.by_priority(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'priority_id',
                             :joins => IssuePriority.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count)
        end

        def self.by_category(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'category_id',
                             :joins => IssueCategory.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count)
        end


        def self.by_assigned_to(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'assigned_to_id',
                             :joins => User.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count)
        end

        def self.by_author(project, date_from=nil, date_to=nil, result=nil, issue_count=nil)
          count_and_group_by(:project => project,
                             :field => 'author_id',
                             :joins => User.table_name,
                             :date_from => date_from,
                             :date_to => date_to,
                             :result => result,
                             :issue_count => issue_count)
        end

        def self.count_and_group_by(options)
          project = options.delete(:project)
          select_field = options.delete(:field)
          joins = options.delete(:joins)
          date_from = options.delete(:date_from)
          date_to = options.delete(:date_to)
          count = options.delete(:issue_count)
          res = options.delete(:result)
          result_where = "and #{res}" if res.present?
          if count != 0 || res.present?
            date_where = "and (#{Issue.table_name}.created_on >='#{date_from.to_s + " 00:00:00"}' AND #{Issue.table_name}.created_on <='#{date_to.to_s + " 23:59:59"}')" if date_to.present? && date_from.present?
          else
            date_where = "and (#{Issue.table_name}.id=0)"
          end

          where = "#{Issue.table_name}.#{select_field}=j.id"
          ActiveRecord::Base.connection.select_all("select    s.id as status_id,
                                                s.is_closed as closed,
                                                j.id as #{select_field},
                                                count(#{Issue.table_name}.id) as total
                                              from
                                                  #{Issue.table_name}, #{Project.table_name}, #{IssueStatus.table_name} s, #{joins} j
                                              where
                                                #{Issue.table_name}.status_id=s.id
                                                #{result_where if result_where.present?}
                                                   #{date_where if date_where.present?}
                                                and #{where}
                                                and #{Issue.table_name}.project_id=#{Project.table_name}.id
                                                and #{visible_condition(User.current, :project => project)}
                                              group by s.id, s.is_closed, j.id")
        end



      end
    end
  end
  class String
    def to_bool
      self.downcase == 'true'
    end
  end
  Issue.send(:include, IssuePatch)
  ReportsController.send(:include, CustomFieldsHelper)
  ReportsController.send(:include, ReportsControllerPatch)
  project_module :report_filters do
    permission :view_report_filters, :reports => :issue_report
  end
  menu :project_menu, :report, {:controller => 'reports', :action => 'issue_report'}, :caption => :report, :after => :activity
  settings :default => {'empty' => true}, :partial => 'settings/report_settings'
end
