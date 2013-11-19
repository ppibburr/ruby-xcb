require File.expand_path(File.join(File.dirname(__FILE__),"wm_client.rb"))

module WM
  KeyMods = {
    # Mod (Mod1 == alt) (Mod4 == Super/windows) 
    :MOD1            => XCB::MOD_MASK_1,
    :MOD4		     => XCB::MOD_MASK_4,
    :AltShift        => XCB::MOD_MASK_1 | XCB::MOD_MASK_SHIFT,   # 
    :AltCtrl         => XCB::MOD_MASK_1 | XCB::MOD_MASK_CONTROL, # 
    :Control         => XCB::MOD_MASK_CONTROL                    #
  }
  
  class Manager
    GrabKeys = []
    
    def self.add_key_binding(mod,sym,action,*o)
      GrabKeys << [mod,sym,action].push(*o)
    end
  
    attr_accessor :clients,:screen,:connection
    def initialize screen,conn
      @screen = screen
      @connection = conn
      @clients = []
    end
    
    ROOT_WINDOW_EVENT_MASK = XCB::EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB::EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                                        XCB::EVENT_MASK_ENTER_WINDOW |
                                        XCB::EVENT_MASK_LEAVE_WINDOW |
                                        XCB::EVENT_MASK_STRUCTURE_NOTIFY |
                                        XCB::EVENT_MASK_BUTTON_PRESS |
                                        XCB::EVENT_MASK_BUTTON_RELEASE | 
                                        XCB::EVENT_MASK_FOCUS_CHANGE |
                                        XCB::EVENT_MASK_PROPERTY_CHANGE  
    
    # Apply attributes to the 'root' window to get events rolling 
    def init
      p 9
      window_root = screen[:root];
      p window_root
      mask = XCB::CW_EVENT_MASK;
      values= ary2pary([ ROOT_WINDOW_EVENT_MASK]);
     p 8
      cookie = XCB::change_window_attributes_checked(connection, window_root, mask, values);
      p cookie
      p connection
      
      error = XCB::request_check(connection, cookie);
      
      XCB::flush(connection);
    p 8
      if error.to_ptr != FFI::Pointer::NULL
      p 88
        on_abort(0)
      end
       
      manage_existing()  
    end
    
    ABORT = {0=>"Manager Running",1=>"SIGINT recieved",2=>"EVENT LOOP Error"}
    
    # Ensure proper exiting
    def on_abort code,error=nil
      case code
      when 0
        XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
        XCB::flush(connection)
        puts "Eh? Probally another manger running. Abort ..."   
        XCB::disconnect(connection)
        exit(1)
      when 2
        XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
        XCB::flush(connection)   
        puts "ABORT CODE: #{code}, #{ABORT[code]}\n#{error}"
        puts error.backtrace.join("\n") if error
        XCB::disconnect(connection)
        exit(1) 
      else
        XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
        XCB::flush(connection)   
        puts "ABORT CODE: #{code}, #{ABORT[code]}"
        XCB::disconnect(connection)
        exit(1)      
      end
    end
    
    def self.client_class
      self::Client
    end
    
    MANAGER_REPARENTING  = 0 # Will create a parent window for managed windows
    MANAGER_NON_REPARENT = 1 # ...
    
    # What type of manager are we ...
    MANAGE_MODE = MANAGER_NON_REPARENT
    
    # @return true, if reparenting
    def is_reparenting?
      self.class::MANAGE_MODE == MANAGER_REPARENTING
    end
    
    # @param Integer, w the window to manage
    def manage w
      # do not re-manage a managed window
      if !@clients.find do |c| c.window.id == w or (is_reparenting?() and c.frame_window.id == w) end
        # manage the window unless it's 'transient_for' another
        @clients << self.class.client_class.new(w,self)  unless tw=Window.new(connection,w).transient_for
      
        # Handle transient window
        if tw
          manage_transient(w,tw)
        end
      end
    end
    
    # TODO: handle better
    #
    # @param w,  the window to manage
    # @param tw, the window w is 'transient_for'
    def manage_transient w,tw
      win=Window.new(connection,w)
      win.map()
      win.raise
      win.focus  
    end
    
    # Done at startup
    # Find existing windows to manage
    def manage_existing()   
      Manager.list_windows(connection,screen).map do |w|
        manage(w)
      end
     
      XCB::flush(connection)
    end
    
    CREATE_WINDOW_MASK = XCB::CW_BACK_PIXEL |
               XCB::CW_BORDER_PIXEL |
               XCB::CW_BIT_GRAVITY |
               XCB::CW_WIN_GRAVITY |
               XCB::CW_OVERRIDE_REDIRECT |
               XCB::CW_EVENT_MASK |
               XCB::CW_COLORMAP
    
    # creates a window at x,y of width w and height h with a border of bw
    def create_window x,y,w,h,bw
      window = XCB::generate_id(connection);
      a= [connection, XCB::WINDOW_CLASS_COPY_FROM_PARENT, window, screen[:root],
              x,y,w,h,
              bw, XCB::WINDOW_CLASS_COPY_FROM_PARENT, XCB::WINDOW_CLASS_COPY_FROM_PARENT,
              CREATE_WINDOW_MASK,
              ary2pary([
                screen[:black_pixel],
                screen[:black_pixel],
                XCB::GRAVITY_NORTH_WEST,
                XCB::GRAVITY_NORTH_WEST,
                1,
                Client::FRAME_SELECT_INPUT_EVENT_MASK,
                0
              ])]
      XCB::create_window(*a);
              
      Window.new(connection,window).map()
      XCB::flush(connection)                  
      window
    end
    
    # finds the client representing the window w
    # @return Client|NilClass, a Client when w matches the 'window' of the client or its 'frame' (if reparenting)
    def find_client_by_window(w)
      @clients.find do |c|
        c.window.id == w or (is_reparenting?() and c.frame_window.id == w )
      end
    end
    
    # Find the client for window w and call it's destroy() method
    # @param Integer, w, the window id to find the client for
    def unmanage(w)
      c = find_client_by_window w
      c.destroy() if c
    end   
    
    def on_key_press(e)
      GrabKeys.each do |q|
        if q[0] == e[:state] and q[1] == e[:detail]
          send q[2] if q.length == 3
          send q[2],*q[3..q.length-1] if q.length > 3
        end
      end
      
      return e
    end
    
    # call init()
    # Loop over events and handle them
    def main
      init()
    
      loop do
        while (evt=XCB::wait_for_event(connection)).to_ptr != FFI::Pointer::NULL;
          next unless on_before_event(evt)
          q = evt[:response_type] & ~0x80
          p q unless [6,12,34].index(q)
          case evt[:response_type] & ~0x80
          when 2
            evt = XCB::KEY_PRESS_EVENT_T.new(evt.to_ptr)
            on_key_press(evt)
          when 7
            evt = XCB::ENTER_NOTIFY_EVENT_T.new(evt.to_ptr)
        
            if c = find_client_by_window(evt[:event])
              c.on_enter(evt)
            end
          when 8
            evt = XCB::ENTER_NOTIFY_EVENT_T.new(evt.to_ptr)
        
            if c = find_client_by_window(evt[:event])
              c.on_leave(evt)
            end 
          when 10

          when 18
            puts "GOT UNMAP _NOTIFY"
            evt = XCB::UNMAP_NOTIFY_EVENT_T.new(evt.to_ptr)
          
            if c = find_client_by_window(evt[:window])
              c.on_unmap_notify(evt)
            end
          when 22
            evt = XCB::CONFIGURE_NOTIFY_EVENT_T.new(evt.to_ptr)
                    
            if c = find_client_by_window(evt[:event])
              c.on_configure_notify(evt)
            end 
          when 23
            evt = XCB::CONFIGURE_REQUEST_EVENT_T.new(evt.to_ptr)
              
            if c = find_client_by_window(evt[:window])
              c.on_configure_request(evt)
            end       
          when XCB::MAP_REQUEST
            evt = XCB::MAP_REQUEST_EVENT_T.new(evt.to_ptr)
        
            if c = find_client_by_window(evt[:window])
              c.on_map_request(evt)
            else 
              manage(evt[:window]) 
            end   
          when XCB::CLIENT_MESSAGE 
            evt = XCB::CLIENT_MESSAGE_EVENT_T.new(evt.to_ptr)

          when XCB::DESTROY_NOTIFY
            puts "GOT DESTROY"
            evt = XCB::DESTROY_NOTIFY_EVENT_T.new(evt.to_ptr)

            unmanage(evt[:event])  
          end
              
          on_after_event(evt)
        
          CLib::free evt.to_ptr 
          XCB::flush(connection)  

          Thread.pass
        end
        Thread.pass
    end
      
    rescue => e
    p e
      on_abort(2,e)
    end
    
    # Called before default event handling
    # When overiding, all return values except false,nil
    # allow default event handling
    #
    # @param XCB::GENERIC_EVENT_T, e, the event
    def on_before_event(e)
      return true
    end
    
    # Called after default event handling
    #
    # @param XCB::GENERIC_EVENT_T, e, the event
    def on_after_event(e)
    
    end
    
    # @return Array<Integer>, window id's currently existing
    def self.list_windows(conn,screen)
      tree_c = XCB::query_tree_unchecked(conn,
                    screen[:root]);

      tree_r = XCB::query_tree_reply(conn,
                    tree_c,
                    nil);

      # # Get the tree of the children windows of the current root window */
      if(!(wins = XCB::query_tree_children(tree_r)))
        printf("cannot get tree children");
        raise 
      end

      tree_c_len = XCB::query_tree_children_length(tree_r);
      wins.read_array_of_int(tree_c_len)
    end
  end

  # Base for reparenting window managers  
  class ReparentingManager < Manager
    MANAGE_MODE = Manager::MANAGER_REPARENTING
  end  
end






