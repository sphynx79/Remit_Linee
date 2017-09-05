class Layout

  class << self


  def load
    header
    yield
    footer
  end

  def header
    p "*****************************************"
  end

  def footer
    p "*****************************************"
  end

  end



end
