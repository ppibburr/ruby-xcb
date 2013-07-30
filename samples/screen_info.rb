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

screen = iter[:data];

printf("\n");
printf("Informations of screen %d:\n", screen[:root]);
printf("  width.........: %d\n", screen[:width_in_pixels]);
printf("  height........: %d\n", screen[:height_in_pixels]);
printf("  white pixel...: %d\n", screen[:white_pixel]);
printf("  black pixel...: %d\n", screen[:black_pixel]);
printf("\n");
