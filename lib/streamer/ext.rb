class String
  def c(*codes)
    "\e[#{codes.join(";")}m#{self}\e[0m"
  end

  def u
    gsub(/&(?:lt|gt|amp|quot|apos);/, {
      'amp'   => '&',
      'lt'    => '<',
      'gt'    => '>',
      'apos'  => "'",
      'quot'  => '"',
    })
  end
end
