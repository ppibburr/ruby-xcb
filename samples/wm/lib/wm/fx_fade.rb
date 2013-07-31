module WM
  module FX
    module Fade
      def on_leave e
        IO::popen("transset-df -i #{get_window().id} 0.34")
        super
      end
    
      def on_enter e
        IO::popen("transset-df -i #{get_window().id} 1")
        super
      end    
    end
  end
end
