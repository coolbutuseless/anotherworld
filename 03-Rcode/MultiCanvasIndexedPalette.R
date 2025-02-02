
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' A class for coordinating multiple canvasses each with an indexed palette
#'
#' AnotherWorld uses 4 canvasses each with an indexed palette.
#' 
#' When the game draws something, it gives only the index of the color it
#' wants to draw in.  
#' 
#' When rendering these nativeRaster buffers to screen, the game provides a 
#' palette, and the indexes in the drawing canvas are mapped to colors at 
#' each pixel.
#'
#' @import R6
#' @import nara
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MultiCanvasIndexedPalette <- R6::R6Class(
  "MultiCanvasIndexedPalette",

  public = list(
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' @field screen list of native raster matrices
    #' @field idx current screen index
    #' @field height,width dimensions of canvas
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    screen     = NULL,
    idx        = NULL,
    height     = NULL,
    width      = NULL,
    debug_count = NULL,

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Initialise this object
    #'
    #' @param width,height dimensions in pixels
    #' @param fill index of color for initial background
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    initialize = function(width, height, fill = 0L) {

      self$height <- height
      self$width  <- width
      self$debug_count <- 0L

      self$screen <- lapply(seq(4), function(i) {
        nara::nr_new(width, height, fill = fill)
      })

      self$set_active_screen(1)

      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Which of the 4 canvasses should be set to active?
    #'
    #' @param idx index of canvas
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    set_active_screen = function(idx) {
      stopifnot(idx >= 1, idx <= 4)
      self$idx <- idx
      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Save a canvas to PNG
    #' @param idx index of canvas
    #' @param filename output filename
    #' @param palette a vector of colors  #TODO sanity check this length
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    save = function(idx, filename, palette) {
      stopifnot(idx >= 1, idx <= 4)

      nr <- self$indexed_to_color(idx, palette)
      png::writePNG(nr, filename)

      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' @description Close this device. Compatible API with multi-x11 device
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    close = function() {
      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Clear the specified canvas to the given index
    #' @param idx index of canvas
    #' @param bg color index for background
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    clear = function(idx, bg = 0L) {
      stopifnot(idx >= 1, idx <= 4)

      if (is.null(bg) || is.na(bg) || bg < 0 || bg > 15) {
        stop("Indexed Palette bg bad color idx: ", bg)
      }

      self$screen[[idx]] <- nara::nr_fill(self$screen[[idx]], bg)
      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Copy a canvas into other canvasses
    #' @param src_idx index of source canvas
    #' @param dst_idxs indices of destination canvasses
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    copy = function(src_idx, dst_idxs) {

      stopifnot(src_idx >= 1, src_idx <= 4)
      stopifnot(all(dst_idxs %in% 1:4))

      for (dst_idx in dst_idxs) {
        nara::nr_copy_into(self$screen[[dst_idx]], self$screen[[src_idx]])
      }

      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Add text to the canvas
    #'
    #' Font used is the games bitmap font
    #'
    #' @param text string
    #' @param x,y location
    #' @param color index of color to use must be in range [0, 15]
    #' @param op operation type. 0 = INDEXED DRAW, 1 = OR with current color
    #'        this is used for some drawing effects
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    text = function(text, x, y, color, op = 0L) {

      if (is.null(color) || is.na(color) || color < 0 || color > 15) {
        stop("Indexed Palette text bad color idx: ", color)
      }

      pts <- text_to_points(text)
      if (is.null(pts) || nrow(pts) == 0) {
        return(invisible(self))
      }

      pts$x <- pts$x + x
      pts$y <- pts$y + y

      nr <- self$screen[[self$idx]]
      nara::nr_point(nr, x = pts$x, y = self$height - pts$y + 1, color = color, op = op)
      # nara::nr_points(nr, x = pts$x, y = pts$y, color = color, op = op)

      invisible(self);
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Draw a polygon
    #' @param x,y vectors of coordinates
    #' @param color index of color to use must be in range [0, 15]
    #' @param op operation type. 0 = DRAW, 1 = OR with current color
    #'        this is used for some drawing effects
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    polygon = function(x, y, color, op = 0L) {

      if (is.null(color) || is.na(color) || color < 0 || color > 15) {
        stop("Indexed Palette polygon bad color idx: ", color)
      }

      nr <- self$screen[[self$idx]]
      nara::nr_polygon(nr, x = x, y = self$height - y + 1, fill = color, color = color, op = op)
      # nara::nr_polygon(nr, color, x, y, op)

      invisible(self)
    },

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Draw a polygon
    #' @param x,y vectors of coordinates
    #' @param color index of color to use must be in range [0, 15]
    #' @param op operation type. 0 = DRAW, 1 = OR with current color
    #'        this is used for some drawing effects
    #' @param idx,frame_num,palette see 'save' method
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    polygon_debug = function(x, y, color, op = 0L, idx, frame_num, palette) {

      if (is.null(color) || is.na(color) || color < 0 || color > 15) {
        stop("Indexed Palette polygon bad color idx: ", color)
      }

      nr <- self$screen[[self$idx]]
      nara::nr_polygon(nr, x = x, y = self$height - y + 1, color = color, op = op)
      # nara::nr_polygon(nr, color, x, y, op)

      for (idx in 1:4) {
        filename <- sprintf("working/polygon-debug/%i-%04i-%04i.png", idx, frame_num, self$debug_count)
        message(filename)
        self$save(idx = idx, filename = filename, palette = palette)
        self$debug_count <- self$debug_count + 1L
      }

      invisible(self)
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Convert an indexed canvas into a native raster with color
    #'
    #' @param idx index of canvas
    #' @param palette vector of 16 colors
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    indexed_to_color = function(idx, palette) {
      stopifnot(length(palette) == 16)

      # print(deparse(palette))
      integer_palette <- nara::color_to_integer(palette)

      color_idx <- self$screen[[idx]]
      rgba_ints <- integer_palette[color_idx + 1L]

      final_nr <- matrix(rgba_ints, nrow=nrow(color_idx), ncol=ncol(color_idx))
      class(final_nr) <- 'nativeRaster'
      attr(final_nr, 'channels') <- 4L

      final_nr
    },


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' Show the canvas on the current device
    #' @param idx index of palette
    #' @param palette palette of 16 colors
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    show = function(idx, palette = rev(grey(seq.int(0, 1, length.out = 16)))) {
      stopifnot(length(palette) == 16)

      final_nr <- self$indexed_to_color(idx, palette)

      grid::grid.raster(final_nr, interpolate = FALSE)
      invisible(self)
    },

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #' @description Print to console inforatiion about this object
    #' @param ... ignored
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    print = function(...) {
      cat(
        "MultiCanvasIndexedPalette: Active = [", self$idx,
        "] - ",
        length(self$screen), " screens",
        "\n"
      )
    }
  )
)


if (FALSE) {
  md <- MultiCanvasIndexedPalette$new(width = 320, height = 200)

  md$clear(4, 10)
  nr <- md$show(4)
}



















