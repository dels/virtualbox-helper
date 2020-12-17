#!/usr/bin/env ruby
# coding: utf-8

require 'json'

def read_config config_file
  config_file ||= "./default.json"
  raise "configuration file must exist and be readable" unless File.exist?(config_file) and File.file?(config_file) and File.readable?(config_file)
  raise "could not load configuration file" unless (config = JSON.parse(File.read(config_file)))

  conf = {}

  conf['name'] = config['vm_name']
  conf['vrde_address'] = config['vrde_address'] ||= "localhost"
  conf['vrde_port'] = config['vrde_port']
  conf['hd_size'] = (config['hd_size_in_gb'].to_i * 1024).to_s # file size in MB
  conf['memory_size'] = config['memory_size']
  conf['host_bridge_iface'] = config['bridging_iface']
  conf['mac_addr'] = config['mac_addr'] ||= ""
  conf['cpu_count'] = config['cpu_count'] ||= 2
  conf['hd_file'] = "#{config['hd_files_directory']}/#{conf['name']}/#{conf['name']}.vdi"
  conf['iso_file'] = config['create_from_iso_file']
  conf['ipv6_only_host'] = config['ipv6_only_host'] ||= false
  conf
end

def create_vm conf, create = false
  cmd_arr = []
  cmd_arr << "VBoxManage createvm --name \"#{conf['name']}\" --register"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --memory #{conf['memory_size']} --acpi on --boot1 dvd"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --nic1 bridged --bridgeadapter1 #{conf['host_bridge_iface']} --cableconnected1 on" unless conf['host_bridge_iface'].empty?
  # TODO: make natnetwork configureable
  # and add hint that one can create a natnetwork with this command: VBoxManage natnetwork add --netname natnet1 --network "192.168.0.0/24" --enable --dhcp on
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --nic2 natnetwork --nat-network2 natnet1 --cableconnected2 on" if conf['ipv6_only_host'].eql?('true')
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --macaddress1 #{conf['mac_addr']}" unless  conf['mac_addr'].empty?
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --ostype Debian_64"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --cpus #{conf['cpu_count']}"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --ioapic on"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --hwvirtex on"
  cmd_arr << "VBoxManage createhd --filename #{conf['hd_file']} --size #{conf['hd_size']}"
  cmd_arr << "VBoxManage storagectl \"#{conf['name']}\" --name \"IDE Controller\" --add ide"
  cmd_arr << "VBoxManage storageattach \"#{conf['name']}\" --storagectl \"IDE Controller\" --port 0 --device 0 --type hdd --medium #{conf['hd_file']}"
  cmd_arr << "VBoxManage storageattach \"#{conf['name']}\" --storagectl \"IDE Controller\" --port 1 --device 0 --type dvddrive --medium #{conf['iso_file']}"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --vrde on"
  # TODO make listening address configureable 
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --vrdeaddress #{conf['vrde_address']}"
  cmd_arr << "VBoxManage modifyvm \"#{conf['name']}\" --vrdeport #{conf['vrde_port']}"
  cmd_arr << "VBoxManage startvm #{conf['name']} --type vrdp"
  
  cmd_arr.each do |cmd|
    if create
      system cmd        
    else
      puts "$ #{cmd}"
      puts ""
      puts "For creating the VM run #{$0} create <config file>"
    end
  end
end

if __FILE__ == $0
  puts ""
  if 0 == ARGV.length
    puts "USAGE: #{$0} create <configfilename>"
    exit
  end
  if 2 == ARGV.length
    if ARGV[0].eql?("create")
      create = true
    end
  end
  conf = read_config(ARGV[1])
  raise "no vm_name defined" unless conf['name'] and false == conf['name'].empty?
  puts "vm name:\t\t #{conf['name']}"
  raise "no vrde_address defined" unless conf['vrde_address'] and false == conf['vrde_address'].empty?
  puts "vrde address:\t\t #{conf['vrde_port']}"
  raise "no vrde_port defined" unless conf['vrde_port'] and false == conf['vrde_port'].empty?
  puts "vrde port:\t\t #{conf['vrde_port']}"
  raise "no hd_size_in_gb defined" unless conf['hd_size'] and false == conf['hd_size'].empty?
  puts "hd size:\t\t #{conf['hd_size'].to_i/1024} GB"
  raise "no cpu_count defined" unless conf['cpu_count'] and false == conf['cpu_count'].empty?
  puts "cpus:\t\t\t #{conf['cpu_count']}"
  raise "no memory_size defined" unless conf['memory_size'] and false == conf['memory_size'].empty?
  puts "mem size:\t\t #{conf['memory_size']} MB"
  raise "no bridging_iface defined" unless conf['host_bridge_iface'] and false == conf['host_bridge_iface'].empty?
  puts "bridge dev:\t\t #{conf['host_bridge_iface']}"
  raise "no hd files directoyr(hd_files_directory) defined" unless conf['hd_file'] and false == conf['hd_file'].empty?
  puts "hd file:\t\t #{conf['hd_file']}"
  raise "no iso file (create_from_iso_file) file defined" unless conf['iso_file'] and false == conf['iso_file'].empty?
  puts "iso file:\t\t #{conf['iso_file']}\n\n"
  puts "this will be an ipv6 only host. hence, i will add an NAT nic so that we have ipv4 internet access" if conf['ipv6_only_host'] && conf['ipv6_only_host'].eql?('true')
  
  mac_addr_srv = conf['mac_addr'].empty? ? "random mac addr" : "#{conf['mac_addr']} as mac addr"

  puts "creating vm #{conf['name']} with #{conf['cpu_count']} cpus and #{conf['memory_size']} MB of memory. she will be listening on VRDE port #{conf['vrde_port']} and have #{conf['hd_file']} as hd file."
  puts "I will use #{conf['iso_file']} as iso file. I will be using #{conf['host_bridge_iface']} as bridging interface with #{mac_addr_srv}\n\n"

  raise "ERROR: iso #{conf['iso_file']} not found" if create && false == File.exists?(conf['iso_file'])

  create_vm(conf, create)

  puts "-" * 80
  puts "\nafter first shutdown set disk to first boot and restart the machine with:\n\n"
  puts <<EOF
  VBoxManage modifyvm #{conf['name']} --boot1 disk
  VBoxManage startvm #{conf['name']} --type vrdp
EOF
  puts
  puts "-" * 80
end
