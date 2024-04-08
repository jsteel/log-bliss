class HelpRenderer
  def initialize
    @window = StaticContentWindow.new(HelpContentProvider.new)
  end

  def win
    @window.win
  end

  def render
    @window.render
  end
end

# TODO Use the same thing for the divider window
class StaticContentWindow
  attr_reader :win

  def initialize(content_provider)
    @content_provider = content_provider
    @win = Curses::Window.new(0, 0, 0, 0)
  end

  def render
    return if @rendered

    @rendered = true

    @win.addstr(@content_provider.content)
    @win.refresh
    @win.nodelay = true
  end
end

class HelpContentProvider
  def content
    help_text = "\n\n\n#{HELP_TEXT}"
  end
end
