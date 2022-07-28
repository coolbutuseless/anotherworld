

suppressPackageStartupMessages({
  library(magrittr)
  library(purrr)
})

load("02-game-data/asset_idx.rda")


frequenceTable <- c(
  0x0CFF, 0x0DC3, 0x0E91, 0x0F6F, 0x1056, 0x114E, 0x1259, 0x136C, 
  0x149F, 0x15D9, 0x1726, 0x1888, 0x19FD, 0x1B86, 0x1D21, 0x1EDE, 
  0x20AB, 0x229C, 0x24B3, 0x26D7, 0x293F, 0x2BB2, 0x2E4C, 0x3110, 
  0x33FB, 0x370D, 0x3A43, 0x3DDF, 0x4157, 0x4538, 0x4998, 0x4DAE, 
  0x5240, 0x5764, 0x5C9A, 0x61C8, 0x6793, 0x6E19, 0x7485, 0x7BBD
);



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Find asset IDs for all palette collections
#
# Each 'palette collection' contains 32 palettes
# Each 'palette' contains 16 colours
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sounds <- keep(asset_idx, ~.x$type_string == 'sound') %>% 
  map_chr('hex')



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Load all WAVs
#
# Use this code if you are going to playback with the '{audio}' package
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wavs <- lapply(sounds, function(hex) {
  soundfile <- sprintf("02-game-data/full/sound/%s.wav", hex)
  # filename <- system.file(soundfile, package = 'anotherworld')
  audio::load.wave(soundfile)
})


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' The best way I have foundto play sound on a mac is to use the 'afplay' 
#' command line utility.
#' 
#' When I have trie dto plaback sound from R using `audio::play()` I get a lot
#' of stuttering and truncated sounds.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
play_sound_mac_afplay <- function(hex, freq, volume, channel) {
  
  if (volume == 0) {
    return()
  }
  
  if (!hex %in% sounds) {
    message("This is not a sound: ", hex)
    return()
  }
  
  soundfile <- sprintf("02-game-data/full/sound/%s.wav", hex)
  
  play_freq <- frequenceTable[freq + 1] / 8000
  
  # afplay
  #   -r   = playback rate multiplier.
  #   -v   = volume on some weird logarithmic scale where 1 = normal, 255 = load, 0 = silet.
  # Note that a volume of ZERO means to silence the channel, but there's no
  # capacity for that in 'afplay'
  cmd <- sprintf("afplay -v %.1f -r %.1f %s", volume/64 + 0.5, play_freq, soundfile)
  system(cmd, wait = FALSE)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' The best way I have foundto play sound on a mac is to use the 'afplay' 
#' command line utility.
#' 
#' When I have trie dto plaback sound from R using `audio::play()` I get a lot
#' of stuttering and truncated sounds.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
play_sound_mac_audio <- function(hex, freq, volume, channel) {
  
  if (!hex %in% sounds) {
    message("This is not a sound: ", hex)
    return()
  }
  
  audio::play(wavs[[hex]])
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Help wanted.  What's a good non-blocking audio player on the command line?
# Need support for 'freq' and 'volume' parameters if possible.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
play_sound_unix    <- function(hex, freq, volume, channel) {
  
  if (volume == 0) {
    return()
  }
  
  if (!hex %in% sounds) {
    message("This is not a sound: ", hex)
    return()
  }
  
  soundfile <- sprintf("02-game-data/full/sound/%s.wav", hex)
  
  beepr:::play_file(soundfile)
}

play_sound_windows <- function(hex, freq, volume, channel) {}
play_sound_null    <- function(hex, freq, volume, channel) {}