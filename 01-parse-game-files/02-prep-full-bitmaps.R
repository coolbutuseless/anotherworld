
suppressPackageStartupMessages({
  library(magrittr)
  library(purrr)
})

load("02-game-data/asset_idx.rda")
load("02-game-data/asset.rda")
source("03-Rcode/cindex-and-bitwise-ops.R")


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Unpack a bitmap to a more usable integer matrix.
#
# Each integer is in the range [0-15] and represents a colour
# chosen from a palette.
#
# Current issue (Mikefc Feb 2022) I don't know which pallette goes with
# an image!
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Which assets are type=2 i.e. bitmaps
#
#  values in 'bm_ids' are the integer indexes of the bitmaps
#  names of 'bm_ids' are the 2-digit hexadecimal values of the index.
#   
#  in the game, values will be looked-up using the hexadecimal values as a string
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
bm_ids <- keep(asset_idx, ~.x$type == 2) %>% map_int('id')


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Storage space for all bitmaps
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
bitmaps <- list()



for (i in seq_along(bm_ids)) {

  bm_id <- bm_ids[[i]]
  cat(sprintf("bitmap: %2i   Asset Index: %3i (0x%02x)\n", i, bm_id, bm_id))

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Fetch the actual data for the bitmap.
  # All bimaps should be 320*200 with integer values stored as the 
  # high/low nibbles within each byte.
  # i.e. data = 320 * 200 / 2 = 32000 bytes/bitmap
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  bm <- asset[[bm_id + 1]]
  stopifnot(length(bm) == 32000)

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Create an 'integer' copy of the 'raw bytes'
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  buf <- as.integer(bm)

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Space for the unpacked bitmap
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  out <- matrix(0L, 200, 320)

  # unpack the hi/lo nibbles from the data buffer into an image
  offset <- 0
  for ( y in seq(0, 199) ) {
    for ( x in seq(0, 319, by = 8) ) {
      for ( b in seq(0, 7) ) {
        mask = 1 %<<% ( 7 - b );
        color = 0;
        for ( p in 0:3 ) {
          if ( buf[ offset + p * 8000 +1 ] %&% mask ) {
            color <- color %|% (1 %<<% p);
          }
        }
        out[y + 1, x+b + 1] <- color
      }
      offset <- offset + 1;
    }
  }
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # save bitmap
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  storage.mode(out) <- 'integer'
  bitmaps[[i]] <- out

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Save the bitmap to file for perusal. PNGs not currently used in 
  # actual game engine.
  # Note that the values in the bitmap are indexes into a palette, but 
  # the palette will only be known at runtime.
  # So saved PNGs will just be given a sequential grey palette
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  outfile <- sprintf("02-game-data//bitmaps/0x%02i.png", as.integer(names(bm_ids)[i]))
  png(outfile)
  grid::grid.raster(out/max(out))
  invisible(dev.off())
}





#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Save bitmap data
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
names(bitmaps) <- names(bm_ids)
save(bitmaps, file = "02-game-data/bitmaps.rda", compress = 'xz')







