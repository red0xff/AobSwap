#!/usr/bin/ruby
#coding: ascii-8bit

require'io/console';
require'colorize';

if ARGV.include?('-h');
label = <<-LABEL

       d8888          888       .d8888b.                                  
      d88888          888      d88P  Y88b                                 
     d88P888          888      Y88b.                                      
    d88P 888  .d88b.  88888b.   "Y888b.   888  888  888  8888b.  88888b.  
   d88P  888 d88""88b 888 "88b     "Y88b. 888  888  888     "88b 888 "88b 
  d88P   888 888  888 888  888       "888 888  888  888 .d888888 888  888 
 d8888888888 Y88..88P 888 d88P Y88b  d88P Y88b 888 d88P 888  888 888 d88P 
d88P     888  "Y88P"  88888P"   "Y8888P"   "Y8888888P"  "Y888888 88888P"  
                                                                 888      
                                                                 888      
                                                                 888      
LABEL
	puts label.green;
	puts "Usage: ./aobswap.rb [OPTIONS] aob1 aob2 file\nOptions :\n-o output : Copy the contents of file to output, and write modifications to it instead\n\n-i : Ask for confirmation before changing data (interactive)\n\n--architecture=arch : Set the architecture for decompilation, will be used with rasm2\n\n--bits=number : Set architecture bits, will also be used with rasm2\n\n--disassemble=number : Set the number of bytes to disassemble on each request\n\n-h : Display this help and exit\n\nRemarks\n\naob1 can contain the wildcard * (nibbles are supported)";
	exit 0;
end
interactive = ARGV.include?('-i');
output = ARGV[-1];
if ind = ARGV.find_index{|param| param == '-o'}
	output = ARGV[ind+1];
end
architecture = 'x86';
bits = 32;
if arch = ARGV.detect{|param| param =~ /--architecture=.+/}
	architecture = arch[/(?<=architecture=).+$/];
end

if b = ARGV.detect{|param| param =~ /--bits=\d+/}
	bits = b[/\d+/].to_i;
end

d = 30; # number of bytes on each disassembly;
if dis = ARGV.detect{|param| param =~ /--disassemble=\d+/}
	d = dis[/\d+/].to_i;
end

aobs = ARGV.select{|w| w =~ /^(?:[0-9a-f\*]{2}\s*)*[0-9a-f\*]{2}$/};
aobs.map!{|aob| aob.gsub(/\s+/, '').each_char.each_slice(2).map(&:join)};
raise ArgumentError, 'Wrong array of byte formats' if aobs.count != 2 || aobs.any?{|aob| aob[-1].length.odd?};
scan, remplace = aobs;
scan.map!{|e|
	case e
		when '**' then [nil, nil];
		when /[0-9a-f]{2}/ then e.to_i(16).chr;
		when /[0-9a-f]\*/ then [e[0].to_i(16), nil];
		when /\*[0-9a-f]/ then [nil, e[1].to_i(16)];
	end
}
remplace = remplace.map{|e| e.to_i(16).chr}.join;
file = ARGV[-1];
f = File.open(file, 'r+b');
data = f.read;
if file != output
	f.close;
	f = File.open(output, 'wb');
	f.write(data);
end
len = data.length;
writes = 0;
count = scan.count;
(len - count).times{|i|
	found = count.times.all?{|j| 
		if scan[j].is_a?(String)
			scan[j] == data[i+j];
		elsif scan[j].none?
			true;
		elsif scan[j][0]
			data[i+j].ord & 0xf0 == scan[j][0]*16;
		else
			data[i+j].ord & 0xf == scan[j][1];
		end
	}
	
	if found then
		# just to print it
		# show 10 bytes each time
		foundaob = data[i, d].each_char.with_index.map{|c, ind|
			c1, c2 = c.ord.to_s(16).rjust(2,?0).chars;
			if scan[ind] && scan[ind].is_a?(Array)
				c1 = c1.red unless scan[ind][0];
				c2 = c2.red unless scan[ind][1];
			end
			c1 + c2;
		}.join(' ');
		raw = data[i, d].each_char.map{|c| c.ord.to_s(16).rjust(2,?0)}.join;
		puts "[#{'FOUND'.green}] at offset #{i.to_s.green} : pattern : \"#{foundaob}\"";
		if interactive then
			puts 'remplace? (y/n) (d to disassemble)';
			resp = nil;
			disassembled = false;
			loop{
			
				resp = IO.console.getch.downcase.intern;
				break if resp == :y || resp == :n;
				if !disassembled && resp == :d
					disassembly = %x(rasm2 -a #{architecture} -b #{bits} -d "#{raw}").gsub(/\b(?:0x)?\d+\b/){|num| num.green}.gsub(/\b(?:[re]?(?:ax|bx|cx|dx|sp|bp|si|di|ip)|es|fs|gs|ss|st\(\d\)|xmm\d|[abcd][hl])\b/){|reg| reg.light_blue};
					puts "--------------DISASSEMBLY AT OFFSET #{i}-----------------"
					puts disassembly;
					disassembled = true;
				end
			}
			puts resp;
			next if resp == :n;
		end
		writes += 1;
		f.pos = i;
		f.write(remplace);
	end
}
puts "[#{'DONE'.green}]\nSwapped #{writes.to_s.green} AOBs\nOutput saved to #{output.green}";
f.close;
