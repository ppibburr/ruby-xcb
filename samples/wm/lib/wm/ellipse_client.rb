require File.expand_path(File.join(File.dirname(__FILE__),"standard_client.rb"))

module WM
  class EllipseWM < WM::ReparentingManager
    include WM::StandardWM
  
    class self::Client < WM::StandardWM::Client
      BORDER = WM::RED   
    
      # Draws a coloured border around the client when focused
      def render_active_hint
         colcookie = XCB::alloc_color(manager.connection, manager.screen[:default_colormap], *self.class::BORDER);
         reply     = XCB::alloc_color_reply(manager.connection, colcookie, nil);
         values    = ary2pary([reply[:pixel]]);
         
         CLib::free(reply.to_ptr)
         
         XCB::change_window_attributes(manager.connection, get_window.id, XCB::CW_BORDER_PIXEL, values);  
         XCB::flush(manager.connection)  
         
         get_window.configure(XCB::CONFIG_WINDOW_BORDER_WIDTH, ary2pary([1]));    
      end
      
      # Removes the coloured border when not focused
      def remove_active_hint
         values = ary2pary([0]);
         
         XCB::change_window_attributes(manager.connection, get_window.id, XCB::CW_BORDER_PIXEL, values);  
         XCB::flush(manager.connection)      
         
         get_window.configure(XCB::CONFIG_WINDOW_BORDER_WIDTH, ary2pary([0]));    
      end     
    
      # We've been entered (moused over)
      def on_enter e
        # Ensure the 'master' is one below us
        a = manager.get_active_client()
        a.raise() if a unless get_transient_for() # unless we are a transient
        
        # overlap the 'master'
        self.raise()
        # take focus
        self.focus()

        # draw border
        render_active_hint()
      end
      
      # Bye Bye Mouse
      def on_leave e
        # remove the border
        remove_active_hint()
      end
      
      #
      # states
      #
      
      # @return true if non-transient and not the master
      def orbiting?()
        (manager.get_active_client() != self) and !get_transient_for()
      end
      
      # @return true if == master
      def is_master?()
        manager.get_active_client() == self
      end      
    end
  end
end
