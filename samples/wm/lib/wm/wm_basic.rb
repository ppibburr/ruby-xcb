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
    BLUE  = [0,65535,0]
    GREEN = [0,0,65535]
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
	   
		tree = XCB::query_tree_reply(connection,XCB::query_tree(connection,id),nil);
		if (!tree) 
			return nil;
		end

		translateCookie = XCB::translate_coordinates(connection,id,tree[:parent],geom[:x], geom[:y] );

		trans = XCB::translate_coordinates_reply(connection,translateCookie,nil );
		
		if (!trans)
			return nil;
		end
		
	    return [
		  trans[:dst_x],
		  trans[:dst_y],
		  geom[:width],
		  geom[:height]
		]
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
	  # @return the cookie tio check for errors with	  
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

	class Manager
	  attr_accessor :clients,:screen,:connection
	  def initialize screen,conn
		@screen = screen
		@connection = conn
		@clients = []
	  end
	  
	  ROOT_WINDOW_EVENT_MASK = XCB::EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB::EVENT_MASK_SUBSTRUCTURE_NOTIFY |
																				XCB::EVENT_MASK_ENTER_WINDOW |
																				XCB::EVENT_MASK_LEAVE_WINDOW |
																				XCB::EVENT_MASK_STRUCTURE_NOTIFY |
																				XCB::EVENT_MASK_BUTTON_PRESS |
																				XCB::EVENT_MASK_BUTTON_RELEASE | 
																				XCB::EVENT_MASK_FOCUS_CHANGE |
																				XCB::EVENT_MASK_PROPERTY_CHANGE  
	  
	  # Apply attributes to the 'root' window to get events rolling 
	  def init
		window_root = screen[:root];
		mask = XCB::CW_EVENT_MASK;
		values= ary2pary([ ROOT_WINDOW_EVENT_MASK]);
	   
		cookie = XCB::change_window_attributes_checked(connection, window_root, mask, values);
		error = XCB::request_check(connection, cookie);
		XCB::flush(connection);
		
		if error.to_ptr != FFI::Pointer::NULL
		  on_abort(0)
		end
		   
		manage_existing()  
	  end
	  
	  ABORT = {0=>"Manager Running",1=>"SIGINT recieved",2=>"EVENT LOOP Error"}
	  
	  # Ensure proper exiting
	  def on_abort code,error=nil
		case code
		when 0
		  XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
		  XCB::flush(connection)
		  puts "Eh? Probally another manger running. Abort ..."   
		  XCB::disconnect(connection)
		  exit(1)
		when 2
		  XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
		  XCB::flush(connection)   
		  puts "ABORT CODE: #{code}, #{ABORT[code]}\n#{error}"
		  puts error.backtrace.join("\n") if error
		  XCB::disconnect(connection)
		  exit(1) 
		else
		  XCB::set_input_focus(connection, XCB::NONE, XCB::INPUT_FOCUS_POINTER_ROOT, XCB::CURRENT_TIME);
		  XCB::flush(connection)   
		  puts "ABORT CODE: #{code}, #{ABORT[code]}"
		  XCB::disconnect(connection)
		  exit(1)      
		end
	  end
	  
	  def self.client_class
		::Client
	  end
	  
	  MANAGER_REPARENTING  = 0 # Will create a parent window for managed windows
	  MANAGER_NON_REPARENT = 1 # ...
	  
	  # What type of manager are we ...
	  MANAGE_MODE = MANAGER_NON_REPARENT
	  
	  # @return true, if reparenting
	  def is_reparenting?
		self.class::MANAGE_MODE == MANAGER_REPARENTING
	  end
	  
	  # @param Integer, w the window to manage
	  def manage w
	    # do not re-manage a managed window
		if !@clients.find do |c| c.window.id == w or (is_reparenting?() and c.frame_window.id == w) end
		  # manage the window unless it's 'transient_for' another
		  @clients << self.class.client_class.new(w,self)  unless tw=Window.new(connection,w).transient_for
		  
		  # Handle transient window
		  if tw
			manage_transient(w,tw)
		  end
		end
	  end
	  
	  # TODO: handle better
	  #
	  # @param w,  the window to manage
	  # @param tw, the window w is 'transient_for'
	  def manage_transient w,tw
		win=Window.new(connection,w)
		win.map()
		win.raise
		win.focus  
	  end
	  
	  # Done at startup
	  # Find existing windows to manage
	  def manage_existing()   
		Manager.list_windows(connection,screen).map do |w|
		  manage(w)
		end
	   
		XCB::flush(connection)
	  end
	  
	  CREATE_WINDOW_MASK = XCB::CW_BACK_PIXEL |
						   XCB::CW_BORDER_PIXEL |
						   XCB::CW_BIT_GRAVITY |
						   XCB::CW_WIN_GRAVITY |
						   XCB::CW_OVERRIDE_REDIRECT |
						   XCB::CW_EVENT_MASK |
						   XCB::CW_COLORMAP
	  
	  # creates a window at x,y of width w and height h with a border of bw
	  def create_window x,y,w,h,bw
		window = XCB::generate_id(connection);
		a= [connection, XCB::WINDOW_CLASS_COPY_FROM_PARENT, window, screen[:root],
						  x,y,w,h,
						  bw, XCB::WINDOW_CLASS_COPY_FROM_PARENT, XCB::WINDOW_CLASS_COPY_FROM_PARENT,
						  CREATE_WINDOW_MASK,
						  ary2pary([
							  screen[:black_pixel],
							  screen[:black_pixel],
							  XCB::GRAVITY_NORTH_WEST,
							  XCB::GRAVITY_NORTH_WEST,
							  1,
							  Client::FRAME_SELECT_INPUT_EVENT_MASK,
							  0
						  ])]
		XCB::create_window(*a);
						  
		Window.new(connection,window).map()
		XCB::flush(connection)                  
		window
	  end
	  
	  # finds the client representing the window w
	  # @return Client|NilClass, a Client when w matches the 'window' of the client or its 'frame' (if reparenting)
	  def find_client_by_window(w)
		@clients.find do |c|
		  c.window.id == w or (is_reparenting?() and c.frame_window.id == w )
		end
	  end
	  
	  # TODO: 
	  #
	  # ensure window of client for w is mapped, if reparented, destroy the frame
	  def unmanage(w)
		c = find_client_by_window w
		c.destroy() if c
	  end
	  
	  # call init()
	  # Loop over events and handle them
	  def main
		  init()
	  
		  loop do
			while (evt=XCB::wait_for_event(connection)).to_ptr != FFI::Pointer::NULL;
			  puts "Got event: #{evt[:response_type]}"
			  case evt[:response_type] & ~0x80
			  when 7
				p :enter_notify
				evt = XCB::ENTER_NOTIFY_EVENT_T.new(evt.to_ptr)
				if c = find_client_by_window(evt[:event])
				  c.on_enter(evt)
				end
			  when 8
				evt = XCB::ENTER_NOTIFY_EVENT_T.new(evt.to_ptr)
				if c = find_client_by_window(evt[:event])
				  c.on_leave(evt)
				end 
			  when 22
			    evt = XCB::CONFIGURE_NOTIFY_EVENT_T.new(evt.to_ptr)
			    find_closed(evt[:event])			    
				if c = find_client_by_window(evt[:event])
				  c.on_configure_notify(evt)
				end 
			  when 23
				evt = XCB::CONFIGURE_NOTIFY_EVENT_T.new(evt.to_ptr)
			    find_closed(evt[:event])
			  when XCB::MAP_REQUEST
				puts :create_notify
				evt = XCB::MAP_REQUEST_EVENT_T.new(evt.to_ptr)
				manage(evt[:window])    
			  when XCB::CLIENT_MESSAGE
				puts :client_message  
				evt = XCB::CLIENT_MESSAGE_EVENT_T.new(evt.to_ptr)
	            find_closed(evt[:window])
			  when XCB::DESTROY_NOTIFY
				puts :destroy_notify
				evt = XCB::DESTROY_NOTIFY_EVENT_T.new(evt.to_ptr)
				unmanage(evt[:event])                    
			  end 
			  CLib::free evt.to_ptr 
			  XCB::flush(connection)  

			  Thread.pass
			end
			Thread.pass
		  end
		  
	  rescue => e
		on_abort(2,e)
	  end
	  
	  # TODO: better way of ensuring we know that a window was destroyed
	  # destroy the client for window w if w does not exist
	  def find_closed w
		@clients.each do |c|
		w = c.window.id
		
		# These atoms are predefined in the X11 protocol.
		property = 39;
		type = 31;

		cookie = XCB::get_property(connection, 0, w, property, type, 0, 0);
		if ((reply = XCB::get_property_reply(connection, cookie, nil).to_ptr) != FFI::Pointer::NULL)
		else
		  c.destroy()
		  clients.delete(c)
		end
		
		end
	  end
	  
	  # @return Array<Integer>, window id's currently existing
	  def self.list_windows(conn,screen)
		tree_c = XCB::query_tree_unchecked(conn,
									  screen[:root]);

		tree_r = XCB::query_tree_reply(conn,
									  tree_c,
									  nil);



		# # Get the tree of the children windows of the current root window */
		if(!(wins = XCB::query_tree_children(tree_r)))
			printf("cannot get tree children");
		  raise 
		end
		tree_c_len = XCB::query_tree_children_length(tree_r);
		wins.read_array_of_int(tree_c_len)
	  end
	end

    # Manages a window
    # Intended to be subclassed
	class Client
	  FRAME_SELECT_INPUT_EVENT_MASK = XCB::EVENT_MASK_STRUCTURE_NOTIFY |
											  XCB::EVENT_MASK_ENTER_WINDOW |
											  XCB::EVENT_MASK_LEAVE_WINDOW | 
											  XCB::EVENT_MASK_EXPOSURE |
											  XCB::EVENT_MASK_SUBSTRUCTURE_REDIRECT | 
											  XCB::EVENT_MASK_POINTER_MOTION | 
											  XCB::EVENT_MASK_BUTTON_PRESS |
											  XCB::EVENT_MASK_BUTTON_RELEASE	
	
	  attr_accessor :window,:manager
	  def initialize win,mgr
		@window = Window.new(mgr.connection,win)
		@manager = mgr
		setup()
	  end

	  def destroy
		get_window.destroy()

	    if manager.clients.index(self)
	      manager.clients.delete(self)
	    end
	  end

	  attr_reader :frame_window
	  def setup
		if manager.is_reparenting?
		  wgeom = window.geom()
		  geom = [wgeom[:x],wgeom[:y],wgeom[:width],wgeom[:height],0]    
		  
		  @frame_window = Window.new(manager.connection,manager.create_window(*geom))

		  cookie = window.reparent_checked(frame_window, 0, 0);
		  error = XCB::request_check(manager.connection,cookie)  
          XCB::flush(manager.connection);
		end
		
		cookie = XCB::intern_atom(manager.connection, 1, 12,"WM_PROTOCOLS");
		reply = XCB::intern_atom_reply(manager.connection, cookie, nil);
		
		cookie2 = XCB::intern_atom(manager.connection, 0, 16, "WM_DELETE_WINDOW");
		reply2 = XCB::intern_atom_reply(manager.connection, cookie2, nil);
		
		ptr = FFI::MemoryPointer.new(:int)
		ptr.write_int reply2[:atom]
		
		XCB::change_property(manager.connection, 0, window.id, reply[:atom], 4, 32, 1,ptr); 
		XCB::flush(manager.connection);

		window.map()  
		XCB::set_input_focus(manager.connection, 1, window.id, 0);

		XCB::flush(manager.connection);# p error[:error_code];exit                                      
	  end
	 
	  #
	  # These are to be overidden
	  #
	  
	  # when mouse enters
	  def on_enter(e)
		
	  end
	  
	  # when mouse left
	  def on_leave(e)

	  end
	  
	  # configure notify
	  def on_configure_notify(e)
	  
	  end
	  
	  #
	  # Geometry setting and reporting
	  #
	  
	  def rect
		w = get_window
		w.rect
	  end
	  
	  def geom
		w = get_window
		w.geom
	  end
	  
	  def set_position x,y
		w = get_window  
	  
		values = FFI::MemoryPointer.new(:int,2)
		values.write_array_of_int [x,y]
		w.configure( 1 | 2, values);    
	  end
	  
	  def resize(x,y)
		frame_window.resize(x,y) if manager.is_reparenting?
		window.resize(x,y)
	  end
	  
	  def set_rect x,y,w,h
	    qw = get_window()
		qw.set_rect(x,y,w,h)
		window.resize(w,h) unless window.id == qw.id
	  end
	  
	  # If manager is reparenting, return the `frame_window`
	  # Else the `window`
	  #
	  # @return Window, the relevant window
	  def get_window
	    manager.is_reparenting?() ? frame_window : window
	  end
	end

  # Base for reparenting window managers	
  class ReparentingManager < Manager
    MANAGE_MODE = Manager::MANAGER_REPARENTING
  end	
end





