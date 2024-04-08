class HelpRenderer
  attr_reader :win

  def initialize
    @win = Curses::Window.new(0, 0, 0, 0)
  end

  def render
    return if @rendered

    @rendered = true

    @win.addstr("\n\n\n#{HELP_TEXT}")
    @win.refresh
    @win.nodelay = true
  end
end
