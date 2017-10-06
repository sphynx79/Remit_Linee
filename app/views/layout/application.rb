class Layout

  class << self


  def load
    header
    yield
    footer
  end

  def header
    puts "*"*48
  end

  def footer
    puts "*"*48
  end

  end



end
