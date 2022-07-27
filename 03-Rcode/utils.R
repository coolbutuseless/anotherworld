

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# read byte from 'bytecode' at the current 'bytecode_offset'
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read_byte_ <- function() {
  value = bytecode[ bytecode_offset ]
  bytecode_offset <<- bytecode_offset + 1L
  value
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# read word (16 bits) from 'bytecode' at the current 'bytecode_offset'
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read_word_ <- function() {
  value = ( bytecode[ bytecode_offset ] * 256L) + bytecode[ bytecode_offset + 1L ]
  bytecode_offset <<- bytecode_offset + 2L
  value
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Convert an unsigned 16bit value (as read by read_word_) to a signed 16bit value.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
to_signed <- function( value, bits) {
  mask <-  2 ^ (16 - 1)
  value - bitwShiftL(bitwAnd(value, mask), 1)
}

# Original JS
# function to_signed( value, bits ) {
#   const mask = 1 << ( bits - 1 );
#   return value - ( ( value & mask ) << 1 );
# }


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Convert a byte to a 2 digit hex string
#    1 -> "01"
#   32 -> "20"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
as_hex <- function(x) {
  if (x < 0 || x > 255) {
    stop("Invalid as_hex() arg: ", x)
  }
  sprintf("%02x", x)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3 digit hex
#    1  -> "001"
#   32  -> "020"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
as_hex3 <- function(x) {
  toupper(sprintf("%03x", x))
}


