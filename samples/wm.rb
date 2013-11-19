require File.join(File.dirname(__FILE__),"..","lib","xcb.rb")
require File.join(File.dirname(__FILE__),"wm","lib","wm.rb")
require File.join(File.dirname(__FILE__),"wm","lib","wm","fx_fade.rb")

class MyWM < WM::EllipseWM
  class self::Client < WM::EllipseWM::Client
    # Blue looks nice
    BORDER = WM::BLUE # the focused window border color
    
    # Effects only work with a composition manager running
    # Tested with:
    #   xcompmgr - very buggy
    #   unagi    - buggy
    #   compton  - awesome
    #
    #
    # Shutdown the composition manager to regain input
    #
    # Comment the next line to disable composition effects 
    include WM::FX::Fade 
    
    # We write the focused window id
    STATUS = "#{ENV['HOME']}/.mywm_status.txt"
    
    # overide to update the status file
    # dzen2 status tool @ /path/to/wm/scripts/statusbar.rb (requires xdotool, dzen2 and i3status)
    def focus
      super
      
      File.open(STATUS,"w") do |f|
        f.puts "#{window.id}"
      end
    end
  end
    
  #
  # Key bindings
  #

  #                Alt1               t  
  add_key_binding WM::KeyMods[:MOD1], 28, :spawn, "x-terminal-emulator" # launch terminal
  #                Alt1               w
  add_key_binding WM::KeyMods[:MOD1], 25, :spawn, "x-www-browser"       # launch web browser
  #                                   p
  add_key_binding WM::KeyMods[:MOD1], 58, :spawn, "dmenu_run"           # launch dmenu launcher  
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
