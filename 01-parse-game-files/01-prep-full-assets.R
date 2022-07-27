

suppressPackageStartupMessages({
    library(purrr)
})


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Most data in the data banks is compressed with the 'bytekiller' compressor
# This is a very very old-skool compression technique.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("01-parse-game-files/bytekiller.R")


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Utility: unpack a big-endian 4-byte integer
#'
#' @param raw_vec R raw vector with length = 4
#' @return R 32-bit signed integer
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
as_int32 <- function(raw_vec) {
    stopifnot(length(raw_vec) == 4)
    sum(as.integer(raw_vec) * 2^c(32, 16, 8, 0))
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Read data banks from original game
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game_path  <- "00-original-game-files/OutofThi"
bank_files <- sort(list.files(game_path, "Bank", full.names = TRUE))
bank       <- map(bank_files, ~readBin(.x, raw(), n = 1e6, size = 1))


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Parse the game game metadata in "Memlist.bin" into the resource map
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
memlist <- readBin(file.path(game_path, "Memlist.bin"), raw(), 1e6, 1)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Types of data stored in the banks and their integer ID
#                 0         1        2           3           4             5             6 = bank2.mat?
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
data_types <- c('sound', 'music', 'bitmap', 'palette', 'bytecode', 'poly_cinematic', 'null')


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Helper function to extract information about each data resource
# referenced in 'Memlist.bin'
#
#  - id
#  - hex string version of id
#  - data type id and name
#  - bank_idx = which data bank the actual data is in.
#  - offset = position within that databank
#  - packed/unpacked size: information about the bytekiller compression 
#      for this data
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
parse_resource <- function(id) {
    info <- memlist[id*20 + 1:20]
    type <- as.integer(info[2])
    type_string <- data_types[type + 1]

    list(
        id             = id,
        hex            = sprintf("%02x", id),
        type           = type,
        type_string    = type_string,
        bank_idx       = as_int32(info[ 5: 8]),
        offset         = as_int32(info[ 9:12]),
        packed_size    = as_int32(info[13:16]),
        unpacked_size  = as_int32(info[17:20])
    )
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create the index of all assets in the data banks
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
asset_idx <- map(seq(0x00, 0x91), parse_resource) %>%
    setNames( sprintf("%02x", seq(0x00, 0x91)) )



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Extract the data for a given asset
#'
#' @param hex the 2 character hex number for this asset from "00" to "91"
#' 
#' @return uncompressed raw vector of data as byte values
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
extract_asset <- function(hex) {

  if (is.numeric(hex)) {
    hex <- sprintf("%02x", hex)
  }

  # message(hex)

  resource <- asset_idx[[hex]]

  packed_data <- bank[[resource$bank_idx]][resource$offset + seq(resource$packed_size)]

  data <- unpack_bytekiller(packed_data = packed_data, unpacked_size = resource$unpacked_size)

  data
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Extract all asset data
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
asset <- purrr::map(seq(0x00, 0x91), extract_asset) %>%
  setNames( sprintf("%02x", seq(0x00, 0x91)) )


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Save assets
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
save(asset_idx, file = "02-game-data/asset_idx.rda", compress = 'xz')
save(asset    , file = "02-game-data/asset.rda"    , compress = 'xz')



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Compare to reference data from python extract
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rawfiles <- list.files("01-parse-game-files/raw/full/", full.names = TRUE)
idx_names <- basename(tools::file_path_sans_ext(rawfiles))
names(rawfiles) <- idx_names
asset_full <- lapply(rawfiles, function(f) {
  readBin(f, 'raw', n = file.size(f))
})

for (nm in names(asset_full)) {
  print(identical(asset_full[[nm]], asset[[nm]]))
}


rawfiles <- list.files("01-parse-game-files/raw/demo/", full.names = TRUE)
idx_names <- basename(tools::file_path_sans_ext(rawfiles))
names(rawfiles) <- idx_names
asset_demo <- lapply(rawfiles, function(f) {
  readBin(f, 'raw', n = file.size(f))
})

save(asset_demo, file = "02-game-data/asset_demo.rda", compress = 'xz')











