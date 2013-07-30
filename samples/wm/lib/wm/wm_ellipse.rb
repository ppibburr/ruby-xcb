module WM
  # A Window Manager that positions windows in an ellipse around a centered 'master' window
  # Focus Follows Mouse
  # 'orbiting' windows can be swapped into the 'master' position
  # 'orbiting' windows can be bi-directionly shifted.
  class EllipseWM < WM::ReparentingManager
    # Extend's the WM::Client base
    class self::Client < WM::Client
      # Draws a coloured border around the client when focused
      def render_active_hint
         XCB::debug true
         colcookie = XCB::alloc_color(manager.connection, manager.screen[:default_colormap], 50000, 32000, 0);
         reply = XCB::alloc_color_reply(manager.connection, colcookie, nil);
         values=ary2pary([reply[:pixel]]);
         XCB::change_window_attributes(manager.connection, get_window.id, XCB::CW_BORDER_PIXEL, values);  
         XCB::flush(manager.connection)  
         get_window.configure(XCB::CONFIG_WINDOW_BORDER_WIDTH, ary2pary([1]));    
      end
      
      # Removes the coloured border when not focused
      def remove_active_hint
         values=ary2pary([0]);
         XCB::change_window_attributes(manager.connection, get_window.id, XCB::CW_BORDER_PIXEL, values);  
         XCB::flush(manager.connection)      
         get_window.configure(XCB::CONFIG_WINDOW_BORDER_WIDTH, ary2pary([0]));    
      end    
    
      # We've been entered (moused over)
      def on_enter e
        # 'master' is moot if we are the master
      
        # Ensure the 'master' is one below us
        a = manager.get_active_client()
        a.get_window().raise if a
        
        # overlap the 'master'
        get_window.raise
        # take focus
        get_window.focus
        
        # draw border
        render_active_hint()
      end
      
      # Bye Bye Mouse
      def on_leave e
        # remove the border
        remove_active_hint()
      end
    end
    
    # Overide to use our 'client' class
    def self.client_class
      self::Client
    end
   
    attr_accessor :inactive_client_width,:inactive_client_height,:active_client_width,:active_client_height
   
    def initialize *o
      super
      
      # 'orbital' client geometry
      @inactive_client_width = 520
      @inactive_client_height = 390
      
      # 'master' client geometry
      @active_client_width = 800
      @active_client_height = 530    
    end
   
    def manage w
      super
      
      # new client becomes the 'master'
      set_active(clients.last,true)  
    end
    
    def unmanage(w)
      # Find out if the 'master' window is to be removed
      bool = find_client_by_window(w) == @active
      bool = !!@active and bool
      
      super

      # Reset positioning
      @current_degree = 0
      @offset = 0
      
      if bool
        # The 'master' is removed
        # default tiling is performed
        @active = nil
        draw()
      else
        # 'master' is to be retained
        draw(@active)
      end
    end
   
    def get_active_client
      @active
    end   
   
    # @param Boolean bool, true if the client is newly managed, false to perform a swap
    def set_active c,bool=false
      return unless c
      
      # store current 'master'
      o = @active
      
      # update 'master'
      @active = c
      
      # no need to continue
      return if o == @active 
      
      # remove the focus hint from the previous 'master'
      if o
        o.remove_active_hint()
      end
      
      # apply the focus hint to the new 'master'
      @active.render_active_hint()
          
      if o
        if bool
          # the new 'master' is newly managed
          # we get the next rect in the layout and apply to the previous 'master'
          o.set_rect *get_next_client_rect()
        else
          # This is a 'swap', we're done
          swap o,@active
          return(true)
        end
      end
      
      # apply the 'master' rect to the new 'master'
      @active.set_rect *get_active_rect()    
      
      return(true)
    end 
    
    # Some would say 'tile'
    # iterates over each client, excluding the 'master'
    # and sets it's rect an increment of the ellipse
    #
    # @param WM::Client a, the client to be the 'master', defaults to newest managed client
    def draw a = clients.last
      clients.each do |c|
        next if c == a
        
        c.set_rect *get_next_client_rect
      end
      
      set_active(a)
    end  
    
    # Swap rects between clients
    #
    # @param WM::Client c1, the 'a' client
    # @param WM::Client c2, the 'b' client
    def swap c1,c2
      a = c1.rect
      b = c2.rect
      c1.set_rect *b
      c2.set_rect *a
    end
    
    # Centers a rectangle of: width w and height h; on x,y.  
    def center_on  x,y,w,h
      x = x - w / 2
      y = y - h / 2    
      return x,y 
    end
    
    # Gets the x,y,w,h values of the next client rectangle
    # 
    # @return Array<Integer>, the rectangle
    def get_next_client_rect
      max_width=screen[:width_in_pixels]
      max_height=screen[:height_in_pixels]
      
      cx = max_width  * 0.5
      cy = max_height * 0.5
      
      pad_x = 20
      pad_y = 40
      
      yr = 0.5 * (max_height - pad_y - inactive_client_height)
      xr = 0.5 * (max_width - pad_x - inactive_client_width)
      
      a = get_current_degree * (Math::PI / 180.0)
      
      x = cx + xr * Math.cos(a)
      y = cy + yr * Math.sin(a)
        
      increment_current_degree()
        
      x,y = center_on(x,y,inactive_client_width,inactive_client_height)
        
      return x,y,inactive_client_width,inactive_client_height
    end
    
    # Gets the rectanlge for the 'master' location
    def get_active_rect
      x = screen[:width_in_pixels]  * 0.5
      y = screen[:height_in_pixels] * 0.5   
      
      x,y = center_on(x,y,active_client_width,active_client_height)
      
      return x,y,active_client_width,active_client_height
    end  
    
    # Gets the current degree in the ellipse, get_next_client_rect() will increment this
    def get_current_degree
      @offset ||= 0
      @current_degree ||= 0  
    end
    
    # Increments the current degree in the ellipse
    def increment_current_degree
      @current_degree += 30

      if get_current_degree() >= 360 - @offset
        @offset += 15
        @current_degree = @offset  
      end
    end  
  end
end
