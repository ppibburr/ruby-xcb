# statusbar.rb
#
# launch a dzen2 status bar filled with the foucused window name and i3status output
#
# ppibburr tulnor33@gmail.com

i3s  = IO::popen("i3status")
dzen = IO::popen("dzen2 -ta l","w")

while s=i3s.gets
  active = File.open("#{ENV['HOME']}/.mywm_status.txt","r").read.strip
  active = `xdotool getwindowname #{active}`.strip
  active = (0..55).map do |i|
    active[i] || " "
  end.join
  dzen.puts "#{active} | #{s}"
end
