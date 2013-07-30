require File.join(File.dirname(__FILE__),"q.rb")
require 'ffi'

api_info = File.join(File.dirname(__FILE__),"..","..","data","xcb.marshal")
IDS = Marshal.load(open(api_info).read)

module XCB
  module Helper
	def struct n
	  q = IDS.find do |q| q.key == "Struct" and q.value["name"] == n end
	  return q if q
	  return IDS.find do |q| q.key == "Union" and q.value["name"] == n end
	end

	def function n
	  IDS.find do |q| q.key == "Function" and q.value["name"] == n end
	end

	def field(id)
	  IDS.find do |q| q.value["id"] == id end
	end

	def enum! n
	  q = IDS.find do |q| q.key == "Enumeration" and q.value["EnumValue"].find do |e| e["name"] == n end end
	  raise unless q
	  q = q.value["EnumValue"].find do |e| e["name"] == n end
	  q = q ? q["init"].to_i : nil
	  raise unless q
	  q
	rescue => e
	  raise "No Enum Found: #{n}"
	end

	def find_id id
	  IDS.find do |q|
		q.value["id"] == id
	  end
	end  
  end

  extend XCB::Helper

  def self.const_missing c
     if q = struct("xcb_"+c.downcase.to_s)
       zz=[]
       cls = q.value
       
       cls["members"].strip.split(" ").each do |m|
         f = field(m)
        
         next unless f.value["type"]
         t = find_id f.value["type"]
         
    zt=nil
    while t.value["type"]
      zt = t if t.key == "PointerType"# unless find_id(find_id(rt.value["type"]).value["type"]).key == "Struct"
      t = find_id(t.value["type"])
    end
    
    qrt=""
   
    if zt and (t.key != "Struct" and t.key != "Union")
      t = zt
    end
         
         if t.key == "Struct" or t.key == "Union"
           qq = const_get(t.value["name"].upcase.gsub(/^XCB_/,'').to_sym)
         elsif t.key == "PointerType"
           qq = :pointer 
         else
           ss= t.value["name"]
           
           if ss =~ /unsigned (.*)/
             g=''
             h=$1
             unless ss=~/char/
             g = t.value["size"]
             end
             ss = "u#{h}#{g}"
           end
           if ss=~/short int/
             ss="int#{t.value["size"]}"
           end
           qq = ss.to_sym
         end
         a = f.value["location"].split(":")
         ff = find_id(a[0]).value["name"]
         l = open(ff).readlines[a[1].to_i-1]
         if l.split(";").first =~ /\[([0-9]+)\]/
           qq = [qq,$1.to_i]
         end
         zz.push f.value["name"].to_sym,qq
       end
     
       kls = Class.new(FFI::Struct)
       kls.layout *zz
       
       const_set(c,kls)
       
       return kls
     elsif e=enum!("xcb_#{c}".upcase)
       const_set(c,e)
       return e  
     end
  end
end

module XCB
  def self.debug bool=false
    @debug = bool
  end
  
  def self.log m,q
    return unless @debug
    puts "X::DEBUG: "
    send m,q
  end
  
  def self.break! &b
    return unless @debug
    b.call() if b
    raise("DEBUG!")
  end

  extend FFI::Library
  ffi_lib "xcb","xcb-icccm"
  CREATE_NOTIFY = 16
  DESTROY_NOTIFY = 17
  CLIENT_MESSAGE = 33
  MAP_REQUEST = 20
  NONE = 0
  CURRENT_TIME = 0
  
def self.method_missing m,*o,&b
  m = :"xcb_#{m}"
  if fun=function(m.to_s)
    fun = fun.value
    rt = find_id fun["returns"]
    zt=nil
    while rt.value["type"]
      zt = rt if rt.key == "PointerType"# unless find_id(find_id(rt.value["type"]).value["type"]).key == "Struct"
      rt = find_id(rt.value["type"])
    end
    
    qrt=""
   
    if zt and (rt.key != "Struct" and rt.key != "Union")
      rt = zt
    end
    
    if rt.value["name"] == "xcb_connection_t"
      rt = :pointer
      qrt=rt
    elsif (rt.key == "Struct" or rt.key == "Union") and rt.value["name"] != "xcb_connection_t"
      rt = XCB.const_get(rt.value["name"].upcase.gsub(/^XCB_/,''))
      qrt = rt
      rt= rt.by_ref
    else
      if rt.key == "PointerType"
        rt = :pointer
      else
        rt = rt.value["name"]
        if rt =~ /unsigned (.*)/  
          rt = "u#{$1}"
        end
        if rt =~ /short int/
          rt = "uint8"
        end
        rt=rt.to_sym
        qrt = ":#{rt}"
      end
    end
    
    args = fun["Argument"].map do |a|
      at = nil
      t = find_id(a["type"])
      if t.key == "PointerType"
        at = :pointer
      else
        while t.value["type"]
          t = find_id(t.value["type"])
        end
        at = t.value["name"]
        if at =~ /unsigned (.*)/
        
          at = "u#{$1}"
        end
        if at=~/short int/
          at = "int8"
        end
        if st=struct(at)
          at = const_get(at.gsub("xcb_","").upcase).by_ref
        else
          at = at.to_sym
        end
      end
      at
    end

    XCB.send *[:attach_function,m,args,rt]

    XCB.module_eval do
      class << self;self;end.send :define_method,m.to_s.gsub("xcb_","") do |*qo,&qb|
        XCB.send(m,*qo,&qb)
      end
    end
  
    XCB.send m,*o,&b
  
  else 
    super
  end
end
end

