const bits = <<1, 2:size(8), 3:8, "a":utf8, 4:16-little-signed, 5.0:float-32, 6:unit(2)-size(4)>>

fn bits(x, n) {
  <<x, n:size(x), 1:unit(4)-size(2), "é":utf8, 0x1F:bits, x:bytes, x:utf16, x:utf32, x:utf8_codepoint, x:utf32_codepoint, x:native, x:unsigned>>
}
