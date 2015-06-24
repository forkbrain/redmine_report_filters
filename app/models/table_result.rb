class TableResult
  attr_accessor :period, :unresolved, :total_age, :avg_age

  def initialize(period, unresolved, total_age, avg_age)
    @period = period
    @unresolved = unresolved
    @total_age = total_age
    @avg_age = avg_age
  end
end