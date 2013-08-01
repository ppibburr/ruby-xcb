module CLib
  extend FFI::Library
  ffi_lib "c"
  attach_function :free,[:pointer],:void
end

def ary2pary a
  pt = FFI::MemoryPointer.new(:int,a.length)
  pt.write_array_of_int a
  pt
end

def is_null?(ptr)
  if ptr.respond_to?(:to_ptr)
  return ptr.to_ptr == FFI::Pointer::NULL
  elsif ptr.is_a?(FFI::Pointer) and ptr == FFI::Pointer::NULL
  return true
  else
  return ptr == nil
  end
end

# Implements window managing basics
module WM    
  # Some pre-defined colours
  RED   = [65535,0,0]
  GREEN = [0,65535,0]
  BLUE  = [0,0,65535]    
  BLACK = [0,0,0]
  WHITE = [65535,65535,65535]
        
  # @return XCB::SCREEN_T, screen for connection at number, screen_n
  def self.screen(conn,screen_n)
  screen_max = XCB::setup_roots_length(setup=XCB::get_setup(conn));
  iter = XCB::setup_roots_iterator(setup);  
  iter_p = FFI::MemoryPointer.new(:pointer)
  iter_p.write_pointer iter

  # we want the screen at index screenNum of the iterator
  for i in 0..screen_n.read_int
    XCB::screen_next(iter_p);
  end

  screen = iter[:data];
  end
  
  XCB::SCREEN_T # ensure the binding
  
  class XCB::SCREEN_T
    def method_missing m,*v
      set = nil
    if m.to_s =~ /\=$/
    set = true
    end
    
    if members.index(q=m.to_s.gsub(/\=$/).to_sym)
    if set
           return self[q] = v[0]
      end
      
      return self[q]
    end
    
    super *[m].push(*v)
  end
  end

  screen_n = FFI::MemoryPointer.new(:pointer)
  CONNECTION = XCB::connect(nil,screen_n)
  SCREEN = screen(CONNECTION,screen_n)
end

