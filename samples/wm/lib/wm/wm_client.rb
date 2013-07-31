module WM
  # Manages a window
  # Intended to be subclassed
  class Client

    FRAME_SELECT_INPUT_EVENT_MASK = XCB::EVENT_MASK_STRUCTURE_NOTIFY |
                        XCB::EVENT_MASK_ENTER_WINDOW |
                        XCB::EVENT_MASK_LEAVE_WINDOW | 
                        XCB::EVENT_MASK_EXPOSURE |
                        XCB::EVENT_MASK_SUBSTRUCTURE_REDIRECT | 
                        XCB::EVENT_MASK_POINTER_MOTION | 
                        XCB::EVENT_MASK_BUTTON_PRESS |
                        XCB::EVENT_MASK_BUTTON_RELEASE  
  
    attr_accessor :window,:manager
    def initialize win,mgr
      @window = Window.new(mgr.connection,win)
      @manager = mgr
      setup()
    end

    def destroy
      get_window.destroy()

        if manager.clients.index(self)
        manager.clients.delete(self)
      end
    end

    attr_reader :frame_window
    def setup
    if manager.is_reparenting?
        wgeom = window.geom()
      geom = [wgeom[:x],wgeom[:y],wgeom[:width],wgeom[:height],0]    
      
        @frame_window = Window.new(manager.connection,manager.create_window(*geom))

      cookie = window.reparent_checked(frame_window, 0, 0);
      error = XCB::request_check(manager.connection,cookie)  
          XCB::flush(manager.connection);
    end
    
    cookie = XCB::intern_atom(manager.connection, 1, 12,"WM_PROTOCOLS");
    reply = XCB::intern_atom_reply(manager.connection, cookie, nil);
    
    cookie2 = XCB::intern_atom(manager.connection, 0, 16, "WM_DELETE_WINDOW");
    reply2 = XCB::intern_atom_reply(manager.connection, cookie2, nil);
    
    ptr = FFI::MemoryPointer.new(:int)
    ptr.write_int reply2[:atom]
    
    XCB::change_property(manager.connection, 0, window.id, reply[:atom], 4, 32, 1,ptr); 
    XCB::flush(manager.connection);

        on_map_request(nil)
        self.raise()
         
        XCB::set_input_focus(manager.connection, 1, window.id, 0);
      XCB::flush(manager.connection);# p error[:error_code];exit                                      
    end
   
      def set_transient(w)
        @transient_for = w
      end
      
      def get_transient_for
        @transient_for
      end
    
      def transients
        manager.clients.find_all do |c|
          tc = c.get_transient_for()
          tc == self
        end
      end    
    
      def add_transient w
        manager.clients << c=manager.class.client_class.new(w,manager)

        c.set_transient(self)
        return c
      end
        
    
    # when mouse enters
    def on_enter(e)
    
    end
    
    # when mouse left
    def on_leave(e)

    end
    
    # configure notify
    def on_configure_notify(e)
    
    end
    
    # configure request
    def on_configure_request(e)
    
    end    
    
    # map request
    def on_map_request e
      get_window().map
      if manager.is_reparenting?()
        window.map()
      end
    end
    
    def on_unmap_notify(e)
      get_window().unmap()
    end
    
    #
    # Geometry setting and reporting
    #
    
    def rect
      w = get_window
      w.rect
    end
    
    def geom
      w = get_window
      w.geom
    end
    
    def set_position x,y
      w = get_window  
    
      values = FFI::MemoryPointer.new(:int,2)
      values.write_array_of_int [x,y]
      w.configure( 1 | 2, values);    
    end
    
    def resize(x,y)
      frame_window.resize(x,y) if manager.is_reparenting?
      window.resize(x,y)
    end
    
    def set_rect x,y,w,h
      qw = get_window()
      qw.set_rect(x,y,w,h)
      window.resize(w,h) unless window.id == qw.id
    end
    
    # If manager is reparenting, return the `frame_window`
    # Else the `window`
    #
    # @return Window, the relevant window
    def get_window
      manager.is_reparenting?() ? frame_window : window
    end
  end
end
