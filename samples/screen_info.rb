connection = XCB::connect(nil,nil)
setup      = XCB::get_setup(connection)
iter       = XCB::setup_roots_iterator(setup);  
        
p screen = iter[:data];

printf("\n");
printf("Informations of screen %d:\n", screen[:root]);
printf("  width.........: %d\n", screen[:width_in_pixels]);
printf("  height........: %d\n", screen[:height_in_pixels]);
printf("  white pixel...: %d\n", screen[:white_pixel]);
printf("  black pixel...: %d\n", screen[:black_pixel]);
printf("\n");
