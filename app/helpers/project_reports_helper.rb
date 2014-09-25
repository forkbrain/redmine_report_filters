module ProjectReportsHelper
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
    @chart = ""
    @days = 0
    @created = 0
    @resolved = 0
    session[:period_report] = "daily"
    session[:period_report] = @period if @period.present?
    session[:days_previously] = 0
    session[:days_previously] = @days_previously if @days_previously.present?
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

end
