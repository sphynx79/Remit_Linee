module Transmission
  class Config < Settingslogic
   source File.join(__dir__,"../../config/config.yml")
   namespace ENV['APP_ENV']
   load! 
  end
end






