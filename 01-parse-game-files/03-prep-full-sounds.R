
suppressPackageStartupMessages({
  library(magrittr)
  library(purrr)
})

load("02-game-data/asset_idx.rda")
load("02-game-data/asset.rda")


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Find all sound assets
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sound_idx <- asset_idx %>% purrr::keep(~.x[['type_string']] == 'sound')


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Convert all sounds to WAV using 'sox' on the commandline
# 
# Original audio format is 8khz, single channel signed bytes
#
# For compatability with the '{audio}' package, and with macOS commandline
# utility 'afplay', convert sound to 16bit mono WAV file.
#
#  1. write raw data to file
#  2. system call to run 'sox' to convert to WAV
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
for (meta in sound_idx) {
  data <- asset[[meta$hex]]
  raw_filename <- sprintf("02-game-data/full/sound/%s.raw", meta$hex)
  wav_filename <- sprintf("02-game-data/full/sound/%s.wav", meta$hex)
  writeBin(data, raw_filename, size = 1)

  cmd <- sprintf("sox -r 8000 -b 8 -e signed-integer -c 1 %s -b 16 %s", raw_filename, wav_filename)
  system(cmd)
}


