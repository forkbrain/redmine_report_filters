module R3SupportHelper

  # Fix redmine >3.0.0 issue, internal error
  # Using function from redmine 2.6 (Issue.by_subproject)
  def issue_by_subproject(project)
    ActiveRecord::Base.connection.select_all("select    s.id as status_id,
                                                s.is_closed as closed,
                                                #{Issue.table_name}.project_id as project_id,
                                                count(#{Issue.table_name}.id) as total
                                              from
                                                #{Issue.table_name}, #{Project.table_name}, #{IssueStatus.table_name} s
                                              where
                                                #{Issue.table_name}.status_id=s.id
                                                and #{Issue.table_name}.project_id = #{Project.table_name}.id
                                                and #{visible_condition(User.current, :project => project, :with_subprojects => true)}
                                                and #{Issue.table_name}.project_id <> #{project.id}
                                              group by s.id, s.is_closed, #{Issue.table_name}.project_id") if project.descendants.active.any?
  end

end