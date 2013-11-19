module XCB
  extend FFI::Library
  ffi_lib "libxcb.so"




  def self.method_missing m,*o,&b
    p [:invoke,"xcb_#{m}",o]
    r = send :"xcb_#{m}",*o
    p [:result, r]
    r
  end  
end

class XCB::KEY_PRESS_EVENT_T < FFI::Struct
  layout *[
			:response_type, :uint8, 
			:detail, :uint8, 
			:sequence, :uint16, 
			:time, :uint32, 
			:root, :uint32, 
			:event, :uint32, 
			:child, :uint32, 
			:root_x, :int16, 
			:root_y, :int16, 
			:event_x, :int16, 
			:event_y, :int16, 
			:state, :uint16, 
			:same_screen, :uint8, 
			:pad0, :uint8
		]
end

class XCB::BUTTON_PRESS_EVENT_T < FFI::Struct
  layout *[
			:response_type, :uint8, 
			:detail, :uint8, 
			:sequence, :uint16, 
			:time, :uint32, 
			:root, :uint32, 
			:event, :uint32, 
			:child, :uint32, 
			:root_x, :int16, 
			:root_y, :int16, 
			:event_x, :int16, 
			:event_y, :int16, 
			:state, :uint16, 
			:same_screen, :uint8, 
			:pad0, :uint8
		]
end

class XCB::ENTER_NOTIFY_EVENT_T < FFI::Struct
  layout *[
			:response_type, :uint8,
			:detail, :uint8, 
			:sequence, :uint16, 
			:time, :uint32, 
			:root, :uint32, 
			:event, :uint32, 
			:child, :uint32, 
			:root_x, :int16, 
			:root_y, :int16, 
			:event_x, :int16, 
			:event_y, :int16, 
			:state, :uint16, 
			:mode, :uint8, 
			:same_screen_focus, :uint8
		]
			
end

XCB::attach_function :xcb_connect,[:pointer, :pointer], :pointer
class XCB::SETUP_T < FFI::Struct
  layout *[:status, :uint8,
			:pad0, :uint8,
			:protocol_major_version, :uint16,
			:protocol_minor_version, :uint16,
			:length, :uint16,
			:release_number, :uint32,
			:resource_id_base, :uint32, 
			:resource_id_mask, :uint32, 
			:motion_buffer_size, :uint32, 
			:vendor_len, :uint16, 
			:maximum_request_length, :uint16, 
			:roots_len, :uint8, 
			:pixmap_formats_len, :uint8,
			:image_byte_order, :uint8, 
			:bitmap_format_bit_order, :uint8, 
			:bitmap_format_scanline_unit, :uint8, 
			:bitmap_format_scanline_pad, :uint8, 
			:min_keycode, :uint8, 
			:max_keycode, :uint8, 
			:pad1, [:uint8, 4]
		]
end

XCB::attach_function :xcb_get_setup,[:pointer], XCB::SETUP_T.by_ref
class XCB::SCREEN_T < FFI::Struct
#    xcb_window_t   root; /**<  */
#    xcb_colormap_t default_colormap; /**<  */
#    uint32_t       white_pixel; /**<  */
#    uint32_t       black_pixel; /**<  */
#    uint32_t       current_input_masks; /**<  */
#    uint16_t       width_in_pixels; /**<  */
#    uint16_t       height_in_pixels; /**<  */
#    uint16_t       width_in_millimeters; /**<  */
#    uint16_t       height_in_millimeters; /**<  */
#    uint16_t       min_installed_maps; /**<  */
#    uint16_t       max_installed_maps; /**<  */
#    xcb_visualid_t root_visual; /**<  */
#    uint8_t        backing_stores; /**<  */
#    uint8_t        save_unders; /**<  */
#    uint8_t        root_depth; /**<  */
#    uint8_t        allowed_depths_len; /**<  */

  layout *[
			:root, :uint32,
			:default_colormap, :uint32, 
			:white_pixel, :uint32, 
			:black_pixel, :uint32, 
			:current_input_masks, :uint32, 
			:width_in_pixels, :uint16, 
			:height_in_pixels, :uint16, 
			:width_in_millimeters, :uint16, 
			:height_in_millimeters, :uint16, 
			:min_installed_maps, :uint16, 
			:max_installed_maps, :uint16, 
			:root_visual, :uint32, 
			:backing_stores, :uint8, 
			:save_unders, :uint8, 
			:root_depth, :uint8, 
			:allowed_depths_len, :uint8
		]
end
p XCB::SCREEN_T.methods.sort
class XCB::SCREEN_ITERATOR_T < FFI::Struct
  layout *[
			:data, XCB::SCREEN_T.by_ref,
			:rem, :int8, 
			:index, :int8
		]
end

XCB::attach_function :xcb_setup_roots_iterator,[:pointer], XCB::SCREEN_ITERATOR_T.by_value
XCB::attach_function :xcb_screen_next,[:pointer], :void

def get_screen
#xcb_screen_t*
#get_screen()
#{
	#/* Open the connection to the X server */
	np = FFI::Pointer::NULL
	@q = connection = XCB::connect(np,np);


	#/* Get the first screen */
	p [:setup_rb,@w = setup  = XCB::get_setup(connection)];


	p setup[:status]

	p [:iter_rb, ir=XCB::setup_roots_iterator(setup)]


	iter = ir

	p [:screen_rb,sr=iter[:data]]
	return sr
#}

end

p screen = get_screen

p screen[:root]





