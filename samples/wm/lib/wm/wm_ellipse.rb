require File.expand_path(File.join(File.dirname(__FILE__),"wm_standard.rb"))
require File.expand_path(File.join(File.dirname(__FILE__),"ellipse_client.rb"))

module WM
  #
  # Elliptical layout
  #
  # A centered MASTER window, larger than it's orbitals
  # Orbiting Windows around MASTER
  # Focus Follows Mouse
  # Raise on Enter
  # Stack Order is top: FOCUS, :next MASTER
  #
  # Here is a diagram of a focused orbital
  # Note how it is inset to and above the master
  #
  #============================================#
  #                    PAD_Y
  #                   _________
  # P                |         |________         
  # A           _____|_________|        |___  P
  # D          |               |  FOCUS |   | A
  #            |       MASTER  |________|   | D
  # X          |                    |_______|  
  #            |____________________|   |     X
  #                  |        |_________|
  #                  |________|
  #                    PAD_Y
  #=============================================#
  #
  # KeyBindings exist to: swap an orbital with the current master
  #                       swap an orbital with its previous sibling
  #                                                    next sibling
  #                       force a window to take focus (window at cursor location)
  #                       toggle fullscreen mode
  #                       kill a client
  #
  # Windows have 3 possible sizes/states: orbitial   (smallest)
  #                                       master     (bigger)
  #                                       fullscreen (largest)
  # 
  # Transient windows (ie, dialogs) are always stacked on top of its transient_for window
  # When a window having transients is entered its transients are raised in creation order
  # And the topmost transient is focused
  class EllipseWM < WM::ReparentingManager
    include WM::StandardWM
  
    [
      # Mask                   Sym   Action  Arguments (optional)
      # Alt1                   # Enter
      [WM::KeyMods[:MOD1],     36,   :on_swap_key_press],            # swap the focused window into 'master'
                               # F
      [WM::KeyMods[:MOD1],     41,   :on_fullscreen_key_press],      # toggle fullscreen
                               # Left
      [WM::KeyMods[:MOD1],     113,  :on_swap_previous_key_press],   # swap focused 1 position prior
                               # Right
      [WM::KeyMods[:MOD1],     114,  :on_swap_next_key_press],       # swap focused 1 position next
    ].each do |key_bind|
      add_key_binding(*key_bind)
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
    
    def init
      super
      GrabKeys.each do |k|
        XCB::grab_key(connection, 1, screen[:root], k[0], k[1], XCB::GRAB_MODE_ASYNC, XCB::GRAB_MODE_ASYNC);
      end
      XCB::flush connection
    end
   
    def manage w
      super
      
      # transients don't get 'master'
      c = find_client_by_window(w)  
      return if c.get_transient_for()
      
      # new client becomes the 'master'
      set_active(clients.last,true)  
    end
    
    def unmanage(w)
      # Find out if the 'master' window is to be removed
      bool = (c=find_client_by_window(w)) == @active
      bool = !!@active and bool
      
      super

      # no update neccessary
      return if c and c.get_transient_for()

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
    
    def on_fullscreen_key_press()
      if c=get_focused_client()
        if c.rect[2..3] != [screen[:width_in_pixels]-2,screen[:height_in_pixels]-2]
          c.set_rect(0,0,screen[:width_in_pixels]-2,screen[:height_in_pixels]-2)
        else
          if c == @active
            @active.set_rect *get_active_rect()
          end
          
          draw @active
        end
      end
    end
    
    def on_swap_key_press
      if c=get_focused_client()
        set_active(c) unless c.get_transient_for()
        @active.raise()
        @active.focus()
        
        x,y = @active.rect[2..3].map do |q| q * 0.5 end
        XCB::warp_pointer(connection, 0, @active.get_window.id, 0,0,0,0,x,y);
        XCB::flush connection
      end
    end
    
    def on_swap_next_key_press()
      if c=get_focused_client()
        ica = clients.find_all do |q| q != @active end
        if i1 = ica.index(c)
          sc = nil
          if i1 < ica.length-1
            sc = ica.find do |q| ica.index(q) == i1+1 end
          else
            sc = ica[0]
          end
          
          return if sc == c
          
          swap c,sc
          x,y = c.rect[2..3].map do |q| q * 0.5 end
          XCB::warp_pointer(connection, XCB::NONE, c.get_window.id, 0, 0, 0, 0, x, y);
        end
      end
    end
    
    def on_swap_previous_key_press()
      if c=get_focused_client()
        ica = clients.find_all do |q| q != @active end
        if i1 = ica.index(c)
          sc = nil
          if i1 > 0
            sc = ica.find do |q| ica.index(q) == i1-1 end
          else
            sc = ica.last
          end
          
          return if sc == c
          
          swap c,sc
          x,y = c.rect[2..3].map do |q| q * 0.5 end
          XCB::warp_pointer(connection, XCB::NONE, c.get_window.id, 0, 0, 0, 0, x, y);          
        end
      end
    end    
    
    # Gets the client at point x,y
    # Order of matching is as follows:
    #   if a focused 'orbital' contains the point it is returned
    #   if the 'master' contains point, the master is returned
    #   if an orbital contains the point, it is returned
    #
    # NOTE: when an orbital is raised but not focused, the section overlapping 'master' will not belong to it
    def client_at(qx,qy)
      # Focused orbital overides @active
      if c=get_focused_client()
        x,y,w,h = c.rect
        x1 = x + w
        y1 = y + h
     
        return c if (qx >= x and qx <= x1) and (qy >= y and qy <= y1)    
      end
     
      # @active overides the other orbital's
      x,y,w,h = @active.rect
      x1 = x + w
      y1 = y + h
            
      return @active if (qx >= x and qx <= x1) and (qy >= y and qy <= y1)

      # an orbital or nil
      if hit=clients.find do |c|
      
          x,y,w,h = c.rect
          x1 = x + w
          y1 = y + h
            
          (qx >= x and qx <= x1) and (qy >= y and qy <= y1)
        end

        return hit
      end
    end 
    
    def get_active_client
      @active
    end   
   
    # @param Boolean bool, true if the client is newly managed, false to perform a swap
    def set_active c,bool=false
      return unless c
      return if c.get_transient_for
            
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
      
      # apply the 'master' rect to the new 'master'
      @active.set_rect *get_active_rect()
      
      draw @active    
      
      return(c)
    end 
    
    # Some would say 'tile'
    # iterates over each client, excluding the 'master'
    # and sets it's rect an increment of the ellipse
    #
    # @param WM::Client a, the client to be the 'master', defaults to newest managed client
    def draw a = clients.last
      return unless a
      
      if c=a.get_transient_for
        a = c
      end
      
      clients.find_all do |c| c!= a end.each_with_index do |c,i|
        next if c == a
        next if c.get_transient_for()
        
        n_rect = get_rect_for_client(i)
        
        c.set_rect *n_rect unless n_rect == c.rect
      end
      
      set_active(a)
    end  
    
    # Swap rects between clients
    #
    # @param WM::Client c1, the 'a' client
    # @param WM::Client c2, the 'b' client
    def swap c1,c2
      i1 = clients.index c1
      i2 = clients.index c2
      
      clients[i1] = c2
      clients[i2] = c1
      
      draw @active
    end
    
    # Centers a rectangle of: width w and height h; on x,y.  
    def center_on  x,y,w,h
      x = x - w / 2
      y = y - h / 2    
      return x,y 
    end
    
    def get_placement_angle
      @placement_angle ||= 30
    end
    
    def set_placement_angle(a)
      @placement_angle = a
    end
    
    # Gets the x,y,w,h values of the next client rectangle
    # 
    # @return Array<Integer>, the rectangle
    def get_rect_for_client i
      max_width=screen[:width_in_pixels]
      max_height=screen[:height_in_pixels]
      
      cx = max_width  * 0.5
      cy = max_height * 0.5
      
      pad_x = 20
      pad_y = 40
      
      yr = 0.5 * (max_height - pad_y - inactive_client_height)
      xr = 0.5 * (max_width - pad_x - inactive_client_width)
      
      position = (get_placement_angle() * i)
      if position >= 360
        i = (position - 360 - get_placement_angle) / get_placement_angle()
        position = (get_placement_angle() + 8) * i
        if position >= 360-8
          i = (position - 360 - 8 - get_placement_angle) / get_placement_angle()        
          position = (get_placement_angle() + 16) * i
        end
      end
      
      a = position * (Math::PI / 180.0)
      
      x = cx + xr * Math.cos(a)
      y = cy + yr * Math.sin(a)
        
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
  end
end
