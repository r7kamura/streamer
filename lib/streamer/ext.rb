# -*- coding: utf-8 -*-

class String
  def c(*codes)
    "\e[#{codes.join;}m#{self}\e[0m"
  end

  def u
    gsub(/&(lt|gt|amp|quot|apos);/) do |s|
      {
        'amp'   => '&',
        'lt'    => '<',
        'gt'    => '>',
        'apos'  => "'",
        'quot'  => '"',
      }[$1]
    end
  end
end

#unless Readline.const_defined?(:NATIVE_REFRESH_LINE_METHOD)
  #Readline::NATIVE_REFRESH_LINE_METHOD = Readline.respond_to?(:refresh_line)
#end
#require 'dl/import'
#module Readline
  #begin
    #module LIBREADLINE
      #if DL.const_defined? :Importable
        #extend DL::Importable
      #else
        #extend DL::Importer
      #end
      #pathes = Array(ENV['TERMTTER_EXT_LIB'] || [
        #'/usr/lib64/libreadline.so',
        #'/usr/local/lib64/libreadline.so',
        #'/usr/local/lib/libreadline.dylib',
        #'/opt/local/lib/libreadline.dylib',
        #'/usr/lib/libreadline.so',
        #'/usr/local/lib/libreadline.so',
        #Dir.glob('/lib/libreadline.so*')[-1] || '', # '' is dummy
        #File.join(Gem.bindir, 'readline.dll')
      #])
      #dlload(pathes.find { |path| File.exist?(path)})
      #extern 'int rl_parse_and_bind (char *)'
    #end
    #def self.rl_parse_and_bind(str)
      #LIBREADLINE.rl_parse_and_bind(str.to_s)
    #end
    #unless Readline::NATIVE_REFRESH_LINE_METHOD
      #module LIBREADLINE
        #extern 'int rl_refresh_line(int, int)'
      #end
      #def self.refresh_line
        #LIBREADLINE.rl_refresh_line(0, 0)
      #end
    #end
  #rescue Exception
    #def self.rl_parse_and_bind(str);end
    #def self.refresh_line;end unless Readline::NATIVE_REFRESH_LINE_METHOD
  #end
#end

