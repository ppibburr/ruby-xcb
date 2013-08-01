module WM
  module DesktopWM
    DESKTOP_ALL = 0
    DESKTOP_1 = 1
    DESKTOP_2 = 2
    DESKTOP_3 = 4
    DESKTOP_4 = 8
    
    def set_client_flags c
      c.set_desktop_mask(mask)
    end
    
    def clients_for(mask=get_desktop)
      clients.find_all do |c|
        c.get_desktop_mask & mask > 0
      end
    end
    
    def set_desktop desk
      @desktop = desk
    end
    
    def get_desktop
      @desktop ||= DESKTOP_1
    end
  end
  
  module Client
    def set_desktop_mask mask
      @desktop_mask = mask
    end
    
    def get_desktop_mask
      @desktop_mask ||= DESKTOP_ALL
    end
  end
end
