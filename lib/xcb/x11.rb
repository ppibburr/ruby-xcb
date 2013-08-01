module X11
  extend FFI::Library
  ffi_lib "X11"
  
  attach_function :XWarpPointer,[:pointer,:int,:int,:int,:int,:int,:int,:int,:int],:pointer
  attach_function :XOpenDisplay,[:pointer],:pointer
  attach_function :XFlush,[:pointer],:pointer
  
  def self.warp_pointer *o
    XWarpPointer *o
  end
  
  def self.open_display *o
    XOpenDisplay *o
  end
  
  def self.flush *o
    XFlush *o
  end
end

module XCB
  def self.warp_pointer con,src,dest,sx,sy,sw,sh,dx,dy
    ptr = X11::open_display(nil)
    X11::warp_pointer ptr,src,dest,sx,sy,sw,sh,dx,dy
    X11::flush(ptr)    
  end
end
