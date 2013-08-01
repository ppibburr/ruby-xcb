screen_n   = FFI::MemoryPointer.new(:pointer)
connection = XCB::connect(nil,screen_n)
setup      = XCB::get_setup(connection)
iter       = XCB::setup_roots_iterator(setup);  
        
iter_p = FFI::MemoryPointer.new(:pointer)
iter_p.write_pointer iter
        
# we want the screen at index screenNum of the iterator
for i in 0..screen_n.read_int
  XCB::screen_next(iter_p);
end

screen = iter[:data]

x,y = ARGV[0] || 50, ARGV[1] || 50

XCB::warp_pointer(connection,0,screen[:root],0,0,0,0,x,y)
