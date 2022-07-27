

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Converts a single line of text to point coordinates
#' 
#' @param text string
#'
#' @return data.frame of x/y coordinates of all pixels to be rendered
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
text_to_points_inner <- function(text) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Find the ASCII value of each letter to be processed
  # Then lookup the points for this character
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  char_idx <- utf8ToInt(text) - utf8ToInt(' ') + 1L
  points <- char_points[char_idx]

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Offset each character from the next by 8 pixels in the x-direction
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  for (i in seq_along(points)) {
    points[[i]]$x <- points[[i]]$x + (i-1L) * 8L
  }

  do.call(rbind, points)
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Convert text to a set of points. Text can include carriage returns
#'
#' @param text character string
#'
#' @return data.frame of (x,y) points representing the individual pixels
#'         of each letter
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
text_to_points <- function(text) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Sanity check
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (is.null(text) || length(text) == 0 || nchar(text) == 0) {
    # This happens but I don't know why.   Mikefc 2022-07-26
    # Does NULL text mean something in particular?
    return(NULL)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Split by "\n" and then process one-line-at-a-time to take
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  lines <- strsplit(text, "\n")[[1]]
  points <- lapply(lines, text_to_points_inner)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Offset each line in the y-direction by 8 pixels
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  for (j in seq_along(points)) {
    points[[j]]$y <- points[[j]]$y + (j-1L) * 8L
  }

  do.call(rbind, points)
}






if (FALSE) {
  text <- 'mad as\nHELL'

  pts <- text_to_points(text)

  library(nara)
  nr <- nr_new(300, 200, fill = 'lightblue')

  nr_point(nr, pts$x, 200 - pts$y, colour = 'black')
  grid::grid.raster(nr, interpolate = FALSE)
}

