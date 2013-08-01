require File.expand_path(File.join(File.dirname(__FILE__),"wm_basic.rb"))
require File.expand_path(File.join(File.dirname(__FILE__),"standard_client.rb"))

module WM
  module StandardWM
    GrabKeys = WM::Manager::GrabKeys
    
    GrabKeys.push(*[
      # Alt1+Shift             # f 
      [WM::KeyMods[:AltShift], 41,   :on_force_focus_key_press],     # Force client under mouse to be focused             
                               # k      
      [WM::KeyMods[:AltShift], 45,   :on_force_kill_key_press],      # Force client to be destroyed           

    ])
   
    def manage_transient(w,tw)
      if !(c=find_client_by_window(tw))
        manage(tw)
        c=find_client_by_window(tw)
      end
      
      c.add_transient(w)
    end  
    
    def spawn cmd,*o
      IO::popen(cmd)
    rescue => e
      on_spawn_error(e)
    end
    
    def on_spawn_error(e=nil)
    
    end
    
    def on_force_kill_key_press()
      if c=get_focused_client()
        unmanage(c.get_window())
        c.destroy()
      end
    end 
    
    def on_force_focus_key_press()
      x,y = get_mouse_location
      puts "GOT LOCATION #{x} #{y}"
      if c = client_at(x,y)
        p !!c.get_transient_for()
        puts "Got client: #{c.frame_window.id} for #{c.window.id}"
        if c.frame_window
          c.frame_window.focus
        else
          c.window.focus()
        end
      end
    end     
  
    def get_mouse_location
      cookie = XCB::query_pointer(connection,screen[:root])
      reply = XCB::query_pointer_reply(connection,cookie,nil)

      coords = [reply[:root_x],reply[:root_y]]
      
      CLib::free reply.to_ptr
      
      return coords
    end
    
    def move_mouse x,y
      XCB::warp_pointer(nil,0,screen[:root],0,0,0,0,x,y)
    end
    
    def get_focused_window()
      cookie = XCB::get_input_focus connection
      reply = XCB::get_input_focus_reply(connection,cookie,nil)
      focus = reply[:focus]    
      
      CLib::free reply
      
      return focus
    end

    def get_focused_client()
      if c=find_client_by_window(get_focused_window())
        return c
      end
    end       
    
    # This does not check stack order
    # Overide it to do so
    #
    # @return Client, first to have a rect containing point x,y
    def client_at x,y
       clients_at(x,y).first 
    end
    
    # @return Array<Client>, of clients whose rect contains point x,y
    def clients_at x,y
      clients.find_all do |c|
        cx,cy,w,h = c.rect
        (x >= cx and x <= cx+w) and (y >= cy and y <= cy + h)
      end
    end
  end
end
