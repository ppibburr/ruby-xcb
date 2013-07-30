require File.join(File.dirname(__FILE__),"..","lib","xcb.rb")
require File.join(File.dirname(__FILE__),"wm","lib","wm.rb")

class MyWM < WM::EllipseWM
  def self.client_class
    self::Client
  end
  
  class self::Client < WM::EllipseWM::Client
    BORDER = WM::BLUE
    
    def on_leave e
      IO::popen("transset-df -i #{get_window().id} 0.34")
      super
    end
    
    def on_enter e
      IO::popen(c="transset-df -i #{get_window().id} 1")
      super
    end    
  end
end

begin
  m = MyWM.new WM::SCREEN,WM::CONNECTION
 
  Signal.trap("INT") do
    m.on_abort(1)
  end

  m.main
rescue => e
  puts "OOPS!! #{e} happened."
  exit(1)
end
