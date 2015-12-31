
require 'json'

def read_config config_file
  config_file ||= "./default.json"
  raise "configuration file #{config_file} must be readable" unless File.exist?(config_file) and File.file?(config_file) and File.readable?(config_file)
  raise "could not load configuration file" unless (conf = JSON.parse(File.read(config_file)))

  @vm_name = conf['vm_name']
  @vrdeport = conf['vrde_port']
  @hd_size = (conf['hd_size_in_gb'].to_i * 1024).to_s # file size in MB
  @memory = conf['memory_size']
  @bridge = conf['bridging_iface']
  @mac_addr = conf['mac_addr'] ||= ""
  @cpu_count = conf['cpu_count'] ||= 2
  @hd_file = "#{conf['hd_files_directory']}/#{@vm_name}/#{@vm_name}.vdi"
  @iso_file = conf['create_from_iso_file']
end


if __FILE__ == $0
  puts ""
  if 2 == ARGV.length
    if ARGV[1].eql?("commit")
      @commit = true
    end
  end
  read_config(ARGV[0])
  raise "no vm_name defined" unless @vm_name and false == @vm_name.empty?
  puts "vm name:\t\t #{@vm_name}"
  raise "no vrde_port defined" unless @vrdeport and false == @vrdeport.empty?
  puts "vrde port:\t\t #{@vrdeport}"
  raise "no hd_size_in_gb defined" unless @hd_size and false == @hd_size.empty?
  puts "hd size:\t\t #{@hd_size.to_i/1024} GB"
  raise "no memory_size defined" unless @memory and false == @memory.empty?
  puts "mem size:\t\t #{@memory} MB"
  raise "no bridging_iface defined" unless @bridge and false == @bridge.empty?
  puts "bridge dev:\t\t #{@bridge}"
  raise "no hd files directoyr(hd_files_directory) defined" unless @hd_file and false == @hd_file.empty?
  puts "hd file:\t\t #{@hd_file}"
  raise "no iso file (create_from_iso_file) file defined" unless @iso_file and false == @iso_file.empty?
  puts "iso file:\t\t #{@iso_file}\n\n"

  mac_addr_srv = @mac_addr.empty? ? "random mac addr" : "#{@mac_addr} as mac addr"

  puts "creating vm #{@vm_name} with #{@cpu_count} cpus and #{@memory} MB of memory. she will be listening on VRDE port #{@vrdeport} and have #{@hd_file} as hd file."
  puts "I will use #{@iso_file} as iso file. I will be using #{@bridge} as bridging interface with #{mac_addr_srv}\n\n"

  if @commit && false == File.exists?(@iso_file)
    raise "ERROR: iso #{@iso_file} not found"
  end

  cmd_arr = []
  cmd_arr << "VBoxManage createvm --name \"#{@vm_name}\" --register"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --memory #{@memory} --acpi on --boot1 dvd"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --nic1 bridged --bridgeadapter1 #{@bridge}"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --macaddress1 #{@mac_addr}" unless  @mac_addr.empty?
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --ostype Debian_64"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --cpus #{@cpucount}"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --ioapic on"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --hwvirtex on"
  cmd_arr << "VBoxManage createhd --filename #{@hd_file} --size #{@hd_size}"
  cmd_arr << "VBoxManage storagectl \"#{@vm_name}\" --name \"IDE Controller\" --add ide"
  cmd_arr << "VBoxManage storageattach \"#{@vm_name}\" --storagectl \"IDE Controller\" --port 0 --device 0 --type hdd --medium #{@hd_file}"
  cmd_arr << "VBoxManage storageattach \"#{@vm_name}\" --storagectl \"IDE Controller\" --port 1 --device 0 --type dvddrive --medium #{@iso_file}"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --vrde on"
  cmd_arr << "VBoxManage modifyvm \"#{@vm_name}\" --vrdeport #{@vrdeport}"
  cmd_arr << "VBoxManage startvm #{@vm_name} --type vrdp"

  cmd_arr.each do |cmd|
    if @commit
      system cmd        
    else
      puts "$ #{cmd}"
    end
  end
  puts "-" * 80
  puts "\nafter first shutdown set disk to first boot and restart the machine with:\n\n"
  puts <<EOF
  VBoxManage modifyvm #{@vm_name} --boot1 disk
  VBoxManage startvm #{@vm_name} --type vrdp
EOF
  puts
  puts "-" * 80
end
