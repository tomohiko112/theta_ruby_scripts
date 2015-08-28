require './lib/theta_initiator.rb'
require 'FileUtils'
require 'open3'
require 'optparse'

#Luminance HDR をインストール、luminance-hdr-cliのPath設定が必要です。
#動作環境 Win7/Mac Yosemite
#Option -st set timer(s) / -b set brightness / -t set tonemap

ThetaInitiator.open do |initiator|
	inputs = ARGV.getopts('','s:5','b:-2000,0,2000','t:mantiuk08')
	brightness = inputs['b'].split(",")
	brightness.map!(&:to_i)
	tmo = inputs['t']
	time = inputs['s'].to_i

	if time > 0 then
		puts "Timer Start! #{time} sec"
		sleep time
	end

	current = Dir.pwd

	brightness_num = brightness.length

	t = Time.now
	date = "#{t.year}-#{t.month}-#{t.day}-#{t.hour}#{t.min}#{t.sec}"
	FileUtils.mkdir_p("./outputs/HDR-#{date}")

	object_handles = Array.new(3)
	file_path = Array.new(3)   

	osn =  RbConfig::CONFIG['host_os']
	os = osn =~ /mswin(?!ce)|mingw|cygwin|bccwin/ ? "win" : "other"

	i = 0

	for value in brightness
		initiator.operation(:SetDevicePropValue, 
			[initiator.device_property_code(:ExposureBiasCompensation)],[value].pack('S').unpack('C*'))

		response = initiator.operation(:GetDevicePropValue,
			[initiator.device_property_code(:ExposureBiasCompensation)])
		puts "ExposureBiasCompensation: #{response[:data].pack('C*').unpack('s')[0].inspect}"

		
		initiator.operation :InitiateCapture, [0,0]
		response = initiator.wait_event #InitiateCaptureが終わるまで待機
		
		object_handles[i] = response[:parameters][0]
		initiator.wait_event #object_handles=respose[:parameters][0]が終わるまで待機
		
		i+=1
	end

	i=0
	a=0

	for value in brightness
		puts "GetObject...#{i+1}/#{brightness_num}"
		file_path[i] = "/outputs/HDR-#{date}/theta_pic_#{value}.jpg"
		data_size = File.open(".#{file_path[i]}", "wb") do |f|
			response = initiator.operation(:GetObject, [object_handles[i]]) do |data|
				f.write data
				a+=1
				if a%80 == 0 then
					print ">"
				end
			end
			print "|100|"
			puts""
			puts "#{i+1}/#{brightness_num} Saved (data_size : #{response[:data_size]} byte)"
		end
		i+=1
	end

	i=0
	input_file_path =""

	for value in brightness
		input_file_path += current.to_s  + file_path[i].to_s + " "
		i+=1
	end

	#Open3.capture 出力抑制のため
	luminance = os == "win" ? "luminance-hdr-cli.exe" : "luminance-hdr-cli"

	puts "Create HDR file..."
	Open3.capture3 ("#{luminance} --tmo #{tmo} -o #{current}/outputs/HDR-#{date}/HDR.jpg  #{input_file_path}")
	puts "Finish"
	puts "Create LDR file..."
	Open3.capture3 ("#{luminance} -o #{current}/outputs/HDR-#{date}/LDR.jpg  #{input_file_path}")
	puts "Finish"
end