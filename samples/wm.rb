require File.join(File.dirname(__FILE__),"..","lib","xcb.rb")
require File.join(File.dirname(__FILE__),"wm","lib","wm.rb")
require File.join(File.dirname(__FILE__),"wm","lib","wm","fx_fade.rb")

class MyWM < WM::EllipseWM
  def self.client_class
    self::Client
  end
  
  class self::Client < WM::EllipseWM::Client
    BORDER = WM::BLUE
    
    # Effects only work with a composition manager running
    # Tested with:
    #   xcompmgr - very buggy
    #   unagi    - works the best, will eventually freeze input though
    #
    # Shutdown the composition manager to regain input
    #
    # Comment the next line to disable composition effects 
    include WM::FX::Fade    
  end
end

begin
  m = MyWM.new(WM::SCREEN,WM::CONNECTION)

  Signal.trap("INT") do
    m.on_abort(1)
  end

  m.main
rescue => e
  puts "OOPS!! #{e} happened."
  exit(1)
end
