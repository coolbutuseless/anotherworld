
suppressPackageStartupMessages({
  library(magrittr)
  library(purrr)
})

load("02-game-data/asset_idx.rda")
load("02-game-data/asset.rda")
source("03-Rcode/cindex-and-bitwise-ops.R")


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Find asset IDs for all palette collections
#
# Each 'palette collection' contains 32 palettes
# Each 'palette' contains 16 colors
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
palette_collection_ids <- keep(asset_idx, ~.x$type_string == 'palette') %>% map_int('id')



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Extract a single 16-color palette from a palette collection
#' 
#' @return R character vector with 16 colors
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
create_pal <- function(palette_collection, pal_idx) {
  offset    <- pal_idx * 32
  pal       <- character(16)  # output palette is 16 colors

  for ( i in seq(0, 15) ) {
    color = ( palette_collection[ offset + i * 2 + 1] %<<% 8 ) %|% palette_collection[ offset + i * 2 + 2 ];
    r = ( color %>>% 8 ) %&% 15;
    r = ( r %<<% 4 ) %|% r;
    g = ( color %>>% 4 ) %&% 15;
    g = ( g %<<% 4 ) %|% g;
    b = color %&% 15;
    b = ( b %<<% 4 ) %|% b;
    pal[ i + 1 ] = rgb(r, g, b, maxColorValue = 255)
  }

  pal
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Storage for all palette collections
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
palette_collections <- list()



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# My hacked version of scales::show_col() to output at a nicer aspect ratio
#
# ToDo: 
#   * add palette_index number as title
#   * add x/y indices for easier lookup when debugging
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
my_show_col <- function (colors, labels = TRUE, borders = NULL, cex_label = 1, 
                         ncol = NULL) {
  n <- length(colors)
  ncol <- ncol %||% ceiling(sqrt(length(colors)))
  nrow <- ceiling(n/ncol)
  colors <- c(colors, rep(NA, nrow * ncol - length(colors)))
  colors <- matrix(colors, ncol = ncol, byrow = TRUE)
  old <- par(pty = "s", mar = c(0, 0, 0, 0))
  on.exit(par(old))
  size <- max(dim(colors))
  plot(c(0, size/2), c(0, -size), type = "n", xlab = "", ylab = "", 
       axes = FALSE)
  rect(col(colors) - 1, -row(colors) + 1, col(colors), -row(colors), 
       col = colors, border = borders)
  if (labels) {
    hcl <- farver::decode_color(colors, "rgb", "hcl")
    label_col <- ifelse(hcl[, "l"] > 50, "black", "white")
    text(col(colors) - 0.5, -row(colors) + 0.5, colors, 
         cex = cex_label, col = label_col)
  }
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Parse out all palette collections
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
for (i in seq_along(palette_collection_ids)) {
  
  # Index of this ID as a character string representation of a hexadecimal
  palette_collection_id <- as.character(names(palette_collection_ids)[[i]])

  # Extract this palette collection from assets
  palette_collection    <- as.integer(asset[[palette_collection_id]])

  # Extract all palettes from this collection
  pals <- map(seq(0, 31), ~create_pal(palette_collection, .x))
  palette_collections[i] <- list(pals)

  # Save an image of the palette for reference/debugging. Not used in game
  long_pal <- unlist(pals)
  filename <- sprintf("02-game-data/palettes/0x%s.png", palette_collection_id)
  png(filename, width = 1200, height = 1200)
  # scales::show_col(long_pal, ncol = 16, labels = FALSE)
  my_show_col(long_pal, ncol = 16, labels = FALSE)
  dev.off()

}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Palette collections will be referenced via the hexadecimal string
# representation of the index.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
names(palette_collections) <- names(palette_collection_ids)

save(palette_collections, file = "02-game-data/palette_collections.rda", compress = 'xz')
