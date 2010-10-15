class Shell
  attr_accessor :command, :execute_options

  def done?
    false
  end

  def apply
    execute(command, execute_options || {})
  end
end