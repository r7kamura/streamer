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
