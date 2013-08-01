require File.expand_path(File.join(File.dirname(__FILE__),"wm_client.rb"))

module WM
  module StandardWM
    class Client < WM::Client
      def remove_events
        [window, frame_window].each do |w|
          next unless w
        end
      end
      
      def apply_events
        [window, frame_window].each do |w|
          next unless w
        end   
      end   
      
      def add_transient w
        c = super
        
        position_transient(c)
        c.focus()
        
        return c
      end
      
      def position_transient t
        ox,oy,ow,oh = rect()
        x,y,w,h = t.rect()
       
        x = ox+15
        y = oy+15
        
        if w >= nw=ow-30
          w = nw
        end
        
        if h >= nh=oh-30
          h = nh
        end
         
        t.set_rect x,y,w,h
      end
      
      def raise
        get_window.raise()
        
        transients.each do |c|
          c.raise()
        end
      end
      
      def focus()
        a = [get_window()]
        #transients.each do |t| a << t end
        a.last.focus()
      end
      
      def set_rect *o
        super *o

        # position our tranient windows
        transients.each do |tc|
          position_transient(tc) 
        end
        
        return o       
      end
      
      #
      # states
      #
      
      def is_fullscreen?()
        x,y,w,h = rect
        ([x,y] == [0,0]) and (w >= manager.screen[:width_in_pixels]-2) and (h >= manager.screen[:height_in_pixels]-2)
      end
      
      def is_focus?()
        manager.get_focused_client() == self
      end      
    end
  end
end
