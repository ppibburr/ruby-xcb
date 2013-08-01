module WM
  # Wrap's an Integer representing the window
  # Provides methods for common XCB window functions
  class Window
    attr_reader :id,:is_frame,:connection
    def initialize conn,id
      @id = id
      @connection = conn
    end
    
    alias :_eq_ :"=="
    
    def to_i
      id
    end

    # @return Integer|NilClass, the window we're transient for, or nil if we're not transient
    def transient_for()
      cookie = XCB::icccm_get_wm_transient_for_unchecked(connection, id);

      trans = FFI::MemoryPointer.new(:int);

      q = XCB::icccm_get_wm_transient_for_reply(connection,
                         cookie,
                         trans, nil)

      if q <= 0
        return nil
      end
    
      return trans.read_int
    end 

    # @return XCB::GET_GEOMETRY_REPLY_T, structure of our geometry
    def geom
      geom = XCB::get_geometry_reply(connection, XCB::get_geometry(connection, id),nil);

      if (is_null?(geom))
        return nil;
      end
      geom
    end

    # x,y translated to actual screen location
    # @return Array<Integer>, x,y,w,h values of our geometry
    def rect
      geom = geom()
      return nil unless geom
      
      coords = [
        geom[:x],
        geom[:y],
        geom[:width],
        geom[:height]
      ]
      
      CLib.free(geom.to_ptr)
    
      return coords
    end

    def raise
      values = ary2pary([ XCB::STACK_MODE_ABOVE ]);

      #/* Move the window on the top of the stack */
      configure(XCB::CONFIG_WINDOW_STACK_MODE, values);
    end

    def lower
      values = ary2pary([ XCB::STACK_MODE_BELOW ]);

      #/* Move the window on the top of the stack */
      configure(XCB::CONFIG_WINDOW_STACK_MODE, values);
    end
    
    def focus
      XCB::set_input_focus(connection, 1, id, 0);
      XCB::flush(connection);
    end
    
    def destroy
      XCB::destroy_window(connection,id)
      XCB::flush(connection)
    end  
    
    # make visible
    def map
      XCB::map_window(connection,id)
      XCB::flush(connection);
    end
    
    # make invisible (still exists)
    def unmap
      XCB::unmap_window(connection,id)
      XCB::flush(connection);
    end  
    
    # ...
    def configure *o
      XCB::configure_window(connection,id,*o)
      XCB::flush(connection);
    end
    
    # Reparents a window in to another
    # @param Integer|Window the parent
    def reparent par,*o
      if !par.is_a?(Integer)
        raise "Not a Window or Integer" unless par.is_a?(Window)
        par = par.id
      end
    
      cookie = XCB::reparent_window(connection,id,par,*o)
      XCB::flush(connection);
      cookie
    end

    # Reparents a window in to another
    # @param Integer|Window the parent
    # 
    # @return the cookie to check for errors with    
    def reparent_checked par,*o
      if !par.is_a?(Integer)
        raise "Not a Window or Integer" unless par.is_a?(Window)
        par = par.id
      end
    
      cookie = XCB::reparent_window_checked(connection,id,par,*o)
      XCB::flush(connection);
      cookie
    end  
    
    def resize x,y
      values = FFI::MemoryPointer.new(:uint32,2)
      values.write_array_of_uint32 [x,y]
    
      #/* Resize the window to width = 200 and height = 300 */
      configure(XCB::CONFIG_WINDOW_WIDTH | XCB::CONFIG_WINDOW_HEIGHT, values);
    end  
  
    def set_position x,y
      values = FFI::MemoryPointer.new(:uint32,2)
      values.write_array_of_uint32 [x,y]
      mask = XCB::CONFIG_WINDOW_X | XCB::CONFIG_WINDOW_Y
      configure( mask, values);   
    end  
      
    # Combines resize, set_position
    def set_rect x,y,w,h
      values = FFI::MemoryPointer.new(:uint32,4)
      values.write_array_of_uint32 [x,y,w,h]
      mask = XCB::CONFIG_WINDOW_X | XCB::CONFIG_WINDOW_Y | XCB::CONFIG_WINDOW_WIDTH | XCB::CONFIG_WINDOW_HEIGHT
      configure( mask, values); 
    end    
  end
end
