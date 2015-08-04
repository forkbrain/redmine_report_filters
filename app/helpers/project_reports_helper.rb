module ProjectReportsHelper

  def aggregate(data, criteria)
    a = 0
    data.each { |row|
      match = 1
      criteria.each { |k, v|
        match = 0 unless (row[k].to_s == v.to_s) || (k == 'closed' &&  (v == 0 ? ['f', false] : ['t', true]).include?(row[k]))
      } unless criteria.nil?
      a = a + row["total"].to_i if match == 1
    } unless data.nil?
    a
  end

  def aggregate_link(data, criteria, *args)
    a = aggregate data, criteria
    a > 0 ? link_to(h(a), *args) : '-'
  end

  def aggregate_path(project, field, row, options={})
    parameters = {:set_filter => 1, :subproject_id => '!*', field => row.id}.merge(options)
    project_issues_path(row.is_a?(Project) ? row : project, parameters)
  end

  def link_selected link_id
    render :text => "
    $('.issues').removeClass('selected');
    $('.report').addClass('selected');
    $('##{link_id}').css('font-weight', 'bold');
    $('##{link_id}').css('color', 'black');"
  end

  def query_initialize
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
  end

  def variables_init
    @period = params[:period_report]
    @days_previously = params[:days_previously]
    @include_empty_projects = params[:include_empty_projects] ? true : false
    @accumulate_results = params[:accumulate_results] ? true : false
    @chart = ""
    @days = 0
    @created = 0
    @resolved = 0
    @statuses = IssueStatus.where(is_closed: "false").order("position")
    @selected_statuses = params[:statuses].present? ? IssueStatus.where(:id => params[:statuses]) : []
    session[:period_report] = "daily"
    session[:period_report] = @period if @period.present?
    session[:days_previously] = 0
    session[:days_previously] = @days_previously if @days_previously.present?
    session[:include_empty_projects] = @include_empty_projects
    session[:accumulate_results] = @accumulate_results
  end

  def set_settings
    @plugin_settings = Setting.where(:name => 'plugin_redmine_report_filters').first
    @date_format = Setting.where(:name => 'date_format').first
    @date_format = @date_format.value if @date_format.present?
    @plugin_settings = @plugin_settings.value["settings_closed_statuses"].to_a if @plugin_settings.present?
    @colors = ['#FF3030', '#009900']
  end

  def set_variables
    @table_results = Array.new
    @weeks_all_days = Array.new
    @month_all_days = Array.new
    @weeks_all_days_closed = Array.new
    @month_all_days_closed = Array.new
    @week_days = 0
    @month_days = 0
    @week_days_closed = 0
    @month_days_closed = 0
  end

  def time_in_words(t)

    if t == 0

      0

    else

      min = t(:time_min)
      hour = t(:time_hour)
      day = t(:time_day)
      month = t(:time_month)
      year = t(:time_year)

      x = (t / 60.0).round

      if x < 1
        "< 1#{min}"
      elsif x < 60
        "#{x}#{min}"
      else

        x = (x / 60.0).round

        if x < 24
          "#{x}#{hour}"
        else

          x = (x / 24.0).round

          if x < 30
            "#{x}#{day}"
          else

            x = (x / 30.0).round

            if x < 12
              "#{x}#{month}"
            else

              m = x.modulo(12.0).round
              y = (x / 12.0).floor

              "#{y}#{year} #{m}#{month}"

            end

          end

        end

      end

    end

  end

end
