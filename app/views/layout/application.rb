class Layout

  class << self


  def load
    header
    yield
    footer
  end

  def header
    logger.info "\n"+"*"*57
  end

  def footer
    logger.info "*"*57
  end

  end



end
