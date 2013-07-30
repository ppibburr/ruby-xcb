require File.join(File.dirname(__FILE__),"lib","xcb","q.rb")
require 'xmlsimple'

api_xml = File.join(File.dirname(__FILE__),"data","xcb.xml")
api_info = File.join(File.dirname(__FILE__),"data","xcb.marshal")

system "gccxml #{i = ARGV[0] || "/usr/include/xcb"}/xcb_icccm.h -fxml=#{api_info}"

c=XmlSimple.xml_in(api_xml)

ids = c.keys.map do |k|
  next unless c[k].is_a?(Array)
  n=c[k].map do |ck|
	Q.new k,ck
  end

  n
end.flatten

IDS = ids.find_all do |q|
  next nil if !q
  q.value["id"] 
end

File.open(api_info,"w") do |f| f.puts Marshal.dump(IDS) end	

