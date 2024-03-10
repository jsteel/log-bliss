class HelpRenderer
  attr_reader :win

  def render
    return if @rendered

    @rendered = true

    help_text = "\n\n\n#{HELP_TEXT}"
    @win = Curses::Window.new(0, 0, 0, 0)
    @win.addstr(help_text)
    @win.refresh
    @win.nodelay = true
  end
end
