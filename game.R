
library(grid)
library(eventloop)
library(nara)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Load game assets parsed from original game
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
load("./02-game-data/asset_idx.rda")
load("./02-game-data/asset.rda")
load("./02-game-data/asset_demo.rda")
load("./02-game-data/bank.rda")
load("./02-game-data/bitmaps.rda")
load("./02-game-data/palette_collections.rda")
load("./02-game-data/char_points.rda")



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Load Helper functions 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("03-Rcode/strings.R")
source("03-Rcode/font.R")
source("03-Rcode/MultiCanvasIndexedPalette.R")
source("03-Rcode/Stack.R")
source("03-Rcode/cindex-and-bitwise-ops.R")
source("03-Rcode/sound-playback.R")
source("03-Rcode/detect-os.R")
source("03-Rcode/utils.R")



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Verbose message about status
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
mess <- function(...) {

  message("[",
          sprintf("% 5i", game$frame_count),
          " - ",
          sprintf("% 4i/", game$task_num),
          sprintf("%04x", game$bytecode_offset),
          "] ", ...)

}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup - Size of rendering canvas.
# Do not change these values.
# Instead, adjust the 'display_scale' variable further down.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SCREEN_W  = 320L
SCREEN_H  = 200L


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# These are the addresses of the input registers
#
# e.g. if the user pressed "LEFT" then set the variable
# VAR_HERO_POS_LEFT_RIGHT to -1
# e.g. game$vars[VAR_HERO_POS_LEFT_RIGHT] <- -1
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
VAR_HERO_POS_UP_DOWN     <- 0xe5
VAR_SCROLL_Y             <- 0xf9
VAR_HERO_ACTION          <- 0xfa
VAR_HERO_POS_JUMP_DOWN   <- 0xfb
VAR_HERO_POS_LEFT_RIGHT  <- 0xfc
VAR_HERO_POS_MASK        <- 0xfd
VAR_HERO_ACTION_POS_MASK <- 0xfe
VAR_PAUSE_SLICES         <- 0xff



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Get the current canvas index
#'
#' @param game game object
#' @param num index of canvas. If in range [0,3] then return this specific
#'        canvas index. For 0xfe and 0xff return the current front/back buffer
#'        index
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
get_page <- function( game, num ) {
  if ( num == 0xff ) {
    game$current_page2
  } else if ( num == 0xfe ) {
    game$current_page1
  } else {
    stopifnot( num < 4 )
    num
  }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Set the index of the current drawing buffer
#'
#' @param game game object
#' @param num index of canvas. If in range [0,3] then return this specific
#'        canvas index. For 0xfe and 0xff return the current front/back buffer
#'        index
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
select_page <- function(game, num) {
  game$current_page0 <- get_page(game, num)
  game$device$set_active_screen(game$current_page0 + 1L)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Fill the given page with the given color index
#'
#' @param game game object
#' @param num index of canvas. If in range [0,3] then return this specific
#'        canvas index. For 0xfe and 0xff return the current front/back buffer
#'        index
#' @param color the index of the color within the palette
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
fill_page <- function(game, num, color) {
  num <- get_page(game, num)

  if (color > 15) {
    cat("F")
    color <- 0L
  }

  game$device$clear(num + 1L, color)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Copy one canvas into another
#'
#' @param game game object
#' @param src,dst indices of canvasses
#' @param vscroll vertical offset when copying. TODO: no idea what this means exactly.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
copy_page <- function(game, src, dst, vscroll) {
  force(src)
  force(dst)
  force(vscroll)


  dst = get_page( game, dst )
  if ( src >= 0xfe ) {
    src = get_page( game, src )
    game$device$copy(src + 1L, dst + 1L)
  } else {
    if ( ( src %&% 0x80 ) == 0 ) {
      vscroll = 0
    }
    src = get_page( game, src %&% 3 )
    if ( dst == src ) {
      return()
    }

    if ( vscroll == 0 ) {
      game$device$copy(src + 1L, dst + 1L)
    } else {
      # TODO: vscroll currently does nothing!  Mike Feb 13 2022
      # mess("copy_page ", src, " ", dst, " V: ", vscroll)
      # Mike: copy with vertical offset?  For now i'm just doing a 
      # vanilla copy here.  Use nara::nr_blit() maybe?
      # This effect is used in the 'water' section to shake the screen
      # as rocks fall from above
      game$device$copy(src + 1L, dst + 1L)
    }
  }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Update the dispaly by showing the specified canvas
#' 
#' @param game game object
#' @param num index of canvas to show
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
update_display <- function(game, num) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Ensure we show the correct display if this is a double-buffer switch
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if ( num != 0xfe ) {
    if ( num == 0xff ) {
      tmp = game$current_page1
      game$current_page1 = game$current_page2
      game$current_page2 = tmp
    } else {
      game$current_page1 = get_page( game, num )
    }
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Update palette
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if ( game$next_palette_idx != -1 ) {
    # mess("next pal[1] = ", game$next_palette_idx)
    game$palette <- as_cindex( game$palette_collection[[game$next_palette_idx]] )
    game$next_palette_idx = -1
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Keep track of frames that are actually draw to screen
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  game$frame_count <- game$frame_count + 1L


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Show the page to the user
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  game$device$show(game$current_page1 + 1L, palette = game$palette)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Save screenshots of each canvas?
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (isTRUE(game$save_screenshots)) {
    game$device$save(1, sprintf("working/frames/%05i-a.png", game$frame_count), palette = game$palette)
    game$device$save(2, sprintf("working/frames/%05i-b.png", game$frame_count), palette = game$palette)
    game$device$save(3, sprintf("working/frames/%05i-c.png", game$frame_count), palette = game$palette)
    game$device$save(4, sprintf("working/frames/%05i-d.png", game$frame_count), palette = game$palette)
    game$device$save(game$current_page1 + 1L, sprintf("working/frames/%05i-e.png", game$frame_count), palette = game$palette)
  }

}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Draw text on the current canvas
#'
#' @param num string number
#' @param color color index
#' @param x,y location
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
draw_string <- function( num, color, x, y ) {

  id <- as_hex3(num)
  text <- game_strings[[id]]
  if (is.null(id)) {
    mess("Unknown string ID: ", id)
    return()
  }

  x <- x * 8
  y <- y

  if (color > 15) {
    cat("]", color, sep = "")
    color <- 0L
  }

  game$device$text(text, x, y, color, op = 0L)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Draw a polygon on the current canvas with the given coordinates
#'
#' @param game game object
#' @param color color index
#' @param VX,VY vectors of coordinates
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
draw_polygon <- function(game, color, VX, VY) {

  
  # Create a debug PNG output of all frames which match this
  # 4 = opening scene
  # 1815 = start of coke drinking
  if (game$frame_count == -1) {

    idx       <- game$current_page1 + 1L
    frame_num <- game$frame_count
    palette   <- game$palette

    # According to AnotherWorld.js colours above 15 are meant to map to 
    # a palette_bmp. I.e.
    # if ( color < 16 ) {
    #   rgba[ i ] = palette32[ palette_type * 16 + color ];
    # } else {
    #   rgba[ i ] = palette_bmp[ color - 16 ];
    # }
    # For now I'm just going to use colour=0
    
    if (color < 0 || color > 16) {
      # cat("@@",color, sep="")  #TODO fix
      game$device$polygon_debug(x = as.integer(VX), y = as.integer(VY), colour = 0L, idx = idx, frame_num = frame_num, palette = palette)
    } else if (color == 16) {
      game$device$polygon_debug(x = as.integer(VX), y = as.integer(VY), colour = 8L, op = 1L, idx = idx, frame_num = frame_num, palette = palette) # OR operation
    } else {
      game$device$polygon_debug(x = as.integer(VX), y = as.integer(VY), colour = color, idx = idx, frame_num = frame_num, palette = palette) # basic DRAW op
    }

  } else {

    if (color < 0 || color > 16) {
      # cat("@@",color, sep="")  #TODO fix. What does colour > 16 mean?
      game$device$polygon(x = as.integer(VX), y = as.integer(VY), colour = 0L)
    } else if (color == 16) {
      game$device$polygon(x = as.integer(VX), y = as.integer(VY), colour = 8L, op = 1L) # OR operation
    } else {
      game$device$polygon(x = as.integer(VX), y = as.integer(VY), colour = color) # basic DRAW op
    }

  }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Using ffmpeg and imagemagick to prep some images fore presentation
#
# ffmpeg -y -framerate 20 -pattern_type glob -i 'polygon-debug-opening/*.png' 
#   -c:v libx264 -pix_fmt yuv420p -s 1280x800 -sws_flags neighbor 'polygon-debug-opening.mp4'
#
# convert lester.gif -interpolate Nearest -filter point -resize 400\% lester-big.png
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Draw a polygon on the current canvas given the offset within a data vector
#'
#' This function unpacks the raw data into vectors of x,y coordinates and then
#' calls `draw_polygon()`
#'
#' @param game game object
#' @param data polygon source data vector to be unpacked into vectors of x,y
#'        coordinates
#' @param offset location of coordinates within the `data`
#' @param color color index
#' @param zoom zoom level for size of polygon
#' @param VX,VY vectors of coordinates
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
fill_polygon <- function(game, data, offset, color, zoom, x, y ) {
  w = ( data[ offset ] * zoom / 64 ) ; offset <- offset + 1L
  h = ( data[ offset ] * zoom / 64 ) ; offset <- offset + 1L
  x1 = ( x - w / 2 )
  x2 = ( x + w / 2 )
  y1 = ( y - h / 2 )
  y2 = ( y + h / 2 )
  if ( x1 >= SCREEN_W || x2 < 0 || y1 >= SCREEN_H || y2 < 0 ) {
    return()
  }
  count = data[ offset ]; offset <- offset + 1L
  # print(count)
  stopifnot( ( count %&% 1 ) == 0 );  # Must be even number of coords. TODO MIKE FIXTHIS


  vx_ = x1 + ( ( data[ offset + seq.int(0, 2*(count-1)    , by = 2)] * zoom / 64 ) )
  vy_ = y1 + ( ( data[ offset + seq.int(1, 2*(count-1) + 1, by = 2)] * zoom / 64 ) )

  draw_polygon( game, color, vx_, vy_ )
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Draw a shape made up of 1 or more polygons
#'
#' This function calls `draw_shape()`
#'
#' @param game game object
#' @param data polygon source data vector to be unpacked into vectors of x,y
#'        coordinates
#' @param offset location of coordinates within the `data`
#' @param zoom zoom level for size of polygon
#' @param VX,VY vectors of coordinates
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
draw_shape_parts <- function(game, data, offset, zoom, x, y ) {
  x0 = x - ( data[ offset ] * zoom / 64 ); offset <- offset + 1L
  y0 = y - ( data[ offset ] * zoom / 64 ); offset <- offset + 1L
  count = data[ offset ]; offset <- offset + 1L
  for ( i in seq(0, count) ) {
    addr = ( data[ offset ] %<<% 8 ) %|% data[ offset + 1 ]; offset <- offset + 2L
    x1 = x0 + ( data[ offset ] * zoom / 64 ); offset <- offset + 1L
    y1 = y0 + ( data[ offset ] * zoom / 64 ); offset <- offset + 1L
    color = 0xff
    if ( addr %&% 0x8000 ) {
      color = data[ offset ] %&% 0x7f; offset <- offset + 2L
    }
    draw_shape(game, data, ( ( addr %<<% 1 ) %&% 0xfffe ), color, zoom, x1, y1 )
  }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Draw a shape made up of 1 or more polygons
#'
#' This function calls `fill_polylgon()` if the shape consists of only a
#' single polygon.
#'
#' Otherwise calls `draw_shape_parts()` if this shape itself has multiple parts
#'
#' @param game game object
#' @param data polygon source data vector to be unpacked into vectors of x,y
#'        coordinates
#' @param offset location of coordinates within the `data`
#' @param color color index
#' @param zoom zoom level for size of polygon
#' @param VX,VY vectors of coordinates
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
draw_shape <- function(game, data, offset, color, zoom, x, y ) {
  code = data[ offset ]; offset <- offset + 1L
  if ( code >= 0xc0 ) {
    if ( color %&% 0x80 ) {
      color = code %&% 0x3f
    }
    fill_polygon(game, data, offset, color, zoom, x, y )
  } else {
    if ( ( code %&% 0x3f ) == 2 ) {
      draw_shape_parts(game, data, offset, zoom, x, y )
    }
  }
}

DEBUG <- FALSE


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Show human readable disassembly of each instruction if DEBUG == TRUE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (DEBUG) {
  dis <- function(game, str = '') {
    cat(sprintf("%02x/%04x: (%02x)", game$task_num, game$opstart, game$opcode), str,  "\n")
  }
} else {
  dis <- function(...) {}
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Run the game in the given thread/task
#'
#' @param game game object
#' @param task_num which thread/task to run
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
execute_task <- function(game, task_num) {

  task_paused <- FALSE
  
  while (!task_paused) {
    game$opstart <- game$bytecode_offset
    game$opcode  <- opcode <- game$read_byte()
    if (opcode %&% 0x80) {
      offset = (((opcode %<<% 8) %|% game$read_byte()) %<<% 1) %&% 0xfffe
      x <- game$read_byte()
      y <- game$read_byte()
      h <- y - 199
      if (h > 0) {
        y <- 199
        x <- x + h
      }
      draw_shape(game, game$polygons1, offset, 0xff, 64, x, y)
      dis(game, 'shape 0x80')
    } else if (opcode %&% 0x40) {
      offset = ( game$read_word( ) %<<% 1) %&% 0xfffe
      x = game$read_byte()
      if ( ( opcode %&% 0x20 ) == 0 ) {
        if ( ( opcode %&% 0x10 ) == 0 ) {
          x = ( x %<<% 8 ) %|% game$read_byte()
        } else {
          x = game$vars[ x ]
        }
      } else {
        if ( opcode %&% 0x10 ) {
          x <- x + 256
        }
      }
      y = game$read_byte()
      if ( ( opcode %&% 8 ) == 0 ) {
        if ( ( opcode %&% 4 ) == 0 ) {
          y = ( y %<<% 8 ) %|% game$read_byte()
        } else {
          y = game$vars[ y ]
        }
      }
      polygons = game$polygons1
      zoom = 64
      if ( ( opcode %&% 2 ) == 0 ) {
        if ( opcode %&% 1 ) {
          zoom = game$vars[ game$read_byte() ]
        }
      } else {
        if ( opcode %&% 1 ) {
          polygons = game$polygons2
        } else {
          zoom = game$read_byte()
        }
      }
      draw_shape(game, polygons, offset, 0xff, zoom, x, y )
      dis(game, 'shape 0x40')
    } else {
      stopifnot(opcode <= 0x1a)
      switch(
        as_hex(opcode),
        '00' = {
          num = game$read_byte()
          imm = to_signed( game$read_word(), 16 )
          game$vars[ num ] = imm
          dis(game, sprintf("var[0x%02x] = %04x", num, imm))
        },
        '01' = {
          dst = game$read_byte()
          src = game$read_byte()
          game$vars[ dst ] = game$vars[ src ]
          dis(game, sprintf("var[0x%02x]  = var[0x%02x]", dst, src))
        },
        '02' = {
          dst = game$read_byte()
          src = game$read_byte()
          game$vars[ dst ] <-  game$vars[ dst ] + game$vars[ src ]
          dis(game, sprintf("var[0x%02x] += var[0x%02x]", dst, src))
        },
        '03' = {
          num = game$read_byte()
          imm = to_signed( game$read_word(), 16 )
          game$vars[ num ] <- game$vars[ num ] + imm
          dis(game, sprintf("var[0x%02x] += 0x%04x", num, imm))
        },
        '04' = { # call
          addr = game$read_word()
          game$tasks[[ task_num ]]$stack$push( game$bytecode_offset )
          dis(game, sprintf("call @%04x", addr))
          game$bytecode_offset <- addr
        },
        '05' = { # ret
          game$bytecode_offset <- game$tasks[[ task_num ]]$stack$pop( )
          dis(game, sprintf("return @%04x", game$bytecode_offset))
        },
        '06' = { # yield
          task_paused = TRUE
          dis(game, "yield")
        },
        '07' = { # jmp
          game$bytecode_offset <- game$read_word()
          dis(game, sprintf("jmp @%04x", game$bytecode_offset))
        },
        '08' ={ ## install_task
          num  = game$read_byte()
          addr = game$read_word()
          # mess("install tasks[[", num, "]] <- ", sprintf("%04x", addr))
          game$tasks[[ num ]]$next_offset <- addr
          dis(game, sprintf("install task[0x%02x] <- @%04x", num, addr))
        },
        '09' = { # jmp_nz. Decrement + jump if result is non-zero
          num = game$read_byte()
          game$vars[ num ] <- game$vars[ num ] - 1
          addr = game$read_word()
          if ( game$vars[ num ] != 0 ) {
            game$bytecode_offset <- addr
            dis(game, sprintf("var[0x%02x]--; jmp nonzero @%04x", num, addr))
          } else {
            dis(game, sprintf("var[0x%02x]--", num))
          }
        },
        '0a' = { # jmp_cond
          op = game$read_byte()
          b = game$vars[ game$read_byte() ]
          if ( op %&% 0x80 ) {
            a = game$vars[ game$read_byte() ]
          } else if ( op %&% 0x40 ) {
            a = to_signed( game$read_word(), 16 )
          } else {
            a = game$read_byte()
          }
          addr = game$read_word()
          switch (
            as_hex(op %&% 7),
            '00' = {
              if ( b == a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b == a. jmp @%04x", addr))
              }
            },
            '01' = {
              if ( b != a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b != a. jmp @%04x", addr))
              }
            },
            '02' = {
              if ( b > a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b > a. jmp @%04x", addr))
              }
            },
            '03' = {
              if ( b >= a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b >= a. jmp @%04x", addr))
              }
            },
            '04' = {
              if ( b < a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b < a. jmp @%04x", addr))
              }
            },
            '05' = {
              if ( b <= a ) {
                game$bytecode_offset <- addr
                dis(game, sprintf("b <= a. jmp @%04x", addr))
              }
            }
          )
        },
        '0b' = { # set_palette
          game$next_palette_idx = game$read_word() %>>% 8
          # mess("next pal[0] = ", game$next_palette_idx)
          dis(game, sprintf("nex palette = 0x%02x", game$next_palette_idx))
        },
        '0c' = { # change_tasks_state
          start = game$read_byte()
          end   = game$read_byte()
          state = game$read_byte()
          dis(game, sprintf("task[0x%02x - 0x%02x].state  <- %i", start, end, state))
          if ( state == 2 ) {
            for (i in seq(start, end)) {
              game$tasks[[ i ]]$next_offset <- -2
            }
          } else {
            stopifnot( state == 0 || state == 1 )
            for (i in seq(start, end)) {
              game$tasks[[ i ]]$next_state <- state
            }
          }
        },
        '0d' = { # select_page
          page <- game$read_byte()
          select_page( game, page )
          dis(game, sprintf("Select page[0x%02x]", page))
        },
        '0e' = { # fill_page
          num   = game$read_byte()
          color = game$read_byte()
          fill_page( game, num, color )
          dis(game, sprintf("page[0x%02x] fill: %i", num, color))
        },
        '0f' = { # copy_page
          src = game$read_byte()
          dst = game$read_byte()
          copy_page( game, src, dst, game$vars[ VAR_SCROLL_Y ] )
          dis(game, sprintf("page[0x%02x] <- page[0x%02x]", dst, src))
        },
        '10' = { # update_display
          num = game$read_byte()
          game$delay <- game$delay + game$vars[ VAR_PAUSE_SLICES ] * 1000 / 50
          #console.log( 'delay:' + delay )
          game$vars[ 0xf7 ] = 0
          update_display( game, num )
          dis(game, sprintf("show page[0x%02x]", num))
        },
        '11' = { # remove_task
          game$bytecode_offset <- -1
          task_paused = TRUE
          dis(game, sprintf("Remove this task[0x%02x]", game$task_num))
        },
        '12' = { # draw_string
          num   = game$read_word()
          x     = game$read_byte()
          y     = game$read_byte()
          color = game$read_byte()
          draw_string( num, color, x, y )
          dis(game, sprintf("Draw string [0x%02x]", num))
        },
        '13' = { # sub
          dst = game$read_byte()
          src = game$read_byte()
          game$vars[ dst ] <- game$vars[ dst ] - game$vars[ src ]
          dis(game, sprintf("var[0x%02x] -= var[0x%02x]", dst, src))
        },
        '14' = { # and
          num = game$read_byte()
          imm = game$read_word()
          res = to_signed( ( game$vars[ num ] %&% imm ) %&% 0xffff, 16 )
          # cat(num, imm, game$vars[ num ], game$vars[ num ] %&% imm, ( game$vars[ num ] %&% imm ) %&% 0xffff, res, "\n")
          game$vars[ num ] <- res
          dis(game, sprintf("var[0x%02x] += 0x%04x", num, imm))
        },
        '15' = { # or
          num = game$read_byte()
          imm = game$read_word()
          game$vars[ num ] = to_signed( ( game$vars[ num ] %|% imm ) %&% 0xffff, 16 )
          dis(game, sprintf("var[0x%02x] |= 0x%04x", num, imm))
        },
        '16' = { # shl
          num = game$read_byte()
          imm = game$read_word() %&% 15
          game$vars[ num ] = to_signed( ( game$vars[ num ] %<<% imm ) %&% 0xffff, 16 )
          dis(game, sprintf("var[0x%02x] <<= 0x%04x", num, imm))
        },
        '17' = { # shr
          num = game$read_byte()
          imm = game$read_word() %&% 15
          game$vars[ num ] = to_signed( ( game$vars[ num ] %&% 0xffff ) %>>% imm, 16 )
          dis(game, sprintf("var[0x%02x] >>= 0x%04x", num, imm))
        },
        '18' = { # play_sound
          num     = game$read_word()
          freq    = game$read_byte()
          volume  = game$read_byte()
          channel = game$read_byte()
          # message("0x18 play sound: ", as_hex(num), " ", freq, " ", volume, " ", channel)
          if (game$play_sounds) {
            play_sound(as_hex(num), freq, volume, channel)
          }
          dis(game, sprintf("sound[0x%02x ch:%i]", num, channel))
        },
        '19' = { # load_resource
          num = game$read_word()
          
          # This num can be 16002 which is about loading the next part
          # cat("-->0x19: ", num, "  ")
          
          if ( num > 16000 ) {
            mess("  End of part. Next part: ", num)
            return(num)  
          } else if (num >= 3000) {
            # Load bitmaps.
            # Do nothing here. Bitmaps already loaded/parsed
            # mess("  '19' load bitmap")
            # should also load t3%d.bmp files for transparency (color 0x10)
            # set_palette_bmp( load( bitmaps[ num ][ 0 ], 256 * 3 ) )
            # buffer8.set( load( bitmaps[ num ][ 1 ], SCREEN_W * SCREEN_H ) )
          } else {
            
            hex_num <- as_hex(num)
            dis(game, sprintf("load asset[0x%02x] (%s)", num, asset_idx[[as_hex(num)]]$type_string))
            
            if (asset_idx[[hex_num]]$type_string %in% c('sound', 'music')) {
              # do nothing. 
              # music not currently handled.
              # sound already parsed and ready to play.  See 'play_sound_*()'
            } else {
            
              if ( hex_num %in% names(bitmaps )) {
                mess("Draw bitmap ", num, hex_num)
                # draw_bitmap( num )
              } else {
                
                cat(hex_num, " ")
                cat(asset_idx[[hex_num]]$type_string)
                cat("\n")
              }
              
            }
          }
          
        },
        '1a' = { # play_music
          num      = game$read_word()
          period   = game$read_word()
          position = game$read_byte()
        },
        stop("Unhandled opcode: ", as_hex(opcode))
      )
    }

  } # while(!task_paused)
  
  # cat("-")
  NULL
} # execute_task()



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setting the game parameters to start a particular section
#
# 16000  =  Protection    Not valid for this R version
# 16001  =  Introduction 
# 16002  =  Water        
# 16003  =  Jail         
# 16004  =  City         
# 16005  =  Arena        
# 16006  =  Luxe         
# 16007  =  Final        
# 16008  =  Password     Not valid for this R version
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
load_part <- function( part ) {
  if ( part == 16000 ) { # protection
    game$palette_collection   = as_cindex(palette_collections[['14']]) #load( data14, size14 );
    game$bytecode  = as_cindex(as.integer(asset[['15']]))   #load( data15, size15 );
    game$polygons1 = as_cindex(as.integer(asset[['16']]))   #load( data16, size16 );
    game$polygons2 = NULL                                   #null;
  } else if ( part == 16001 ) { # introduction
    game$palette_collection   = as_cindex(palette_collections[['17']]) #load( data17, size17 );
    game$bytecode  = as_cindex(as.integer(asset[['18']]))   #load( data18, size18 );
    game$polygons1 = as_cindex(as.integer(asset[['19']]))   #load( data19, size19 );
    game$polygons2 = NULL                                   #null;
  } else if ( part == 16002 ) { # water
    game$palette_collection   = as_cindex(palette_collections[['1a']]) #load( data1a, size1a );
    game$bytecode  = as_cindex(as.integer(asset[['1b']]))   #load( data1b, size1b );
    game$polygons1 = as_cindex(as.integer(asset[['1c']]))   #load( data1c, size1c );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16003 ) { # jail
    game$palette_collection   = as_cindex(palette_collections[['1d']]) #load( data1d, size1d );
    game$bytecode  = as_cindex(as.integer(asset[['1e']]))   #load( data1e, size1e );
    game$polygons1 = as_cindex(as.integer(asset[['1f']]))   #load( data1f, size1f );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16004 ) { # 'cite'
    game$palette_collection   = as_cindex(palette_collections[['20']]) #load( data20, size20 );
    game$bytecode  = as_cindex(as.integer(asset[['21']]))   #load( data21, size21 );
    game$polygons1 = as_cindex(as.integer(asset[['22']]))   #load( data22, size22 );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16005 ) { # 'arene'
    game$palette_collection   = as_cindex(palette_collections[['23']]) #load( data23, size23 );
    game$bytecode  = as_cindex(as.integer(asset[['24']]))   #load( data24, size24 );
    game$polygons1 = as_cindex(as.integer(asset[['25']]))   #load( data25, size25 );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16006 ) { # 'luxe'
    game$palette_collection   = as_cindex(palette_collections[['26']]) #load( data26, size26 );
    game$bytecode  = as_cindex(as.integer(asset[['27']]))   #load( data27, size27 );
    game$polygons1 = as_cindex(as.integer(asset[['28']]))   #load( data28, size28 );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16007 ) { # 'final'
    game$palette_collection   = as_cindex(palette_collections[['29']]) #load( data29, size29 );
    game$bytecode  = as_cindex(as.integer(asset[['2a']]))   #load( data2a, size2a );
    game$polygons1 = as_cindex(as.integer(asset[['2b']]))   #load( data2b, size2b );
    game$polygons2 = as_cindex(as.integer(asset[['11']]))   #load( data11, size11 );
  } else if ( part == 16008 ) { # password screen
    game$palette_collection   = as_cindex(palette_collections[['7d']]) #load( data7d, size7d );
    game$bytecode  = as_cindex(as.integer(asset[['7e']]))   #load( data7e, size7e );
    game$polygons1 = as_cindex(as.integer(asset[['7f']]))   #load( data7f, size7f );
    game$polygons2 = NULL                                   #null;
  } else {
    stop("Not a valid game part. Must be integer in range: 16001-16008")
  }

  # Re-init tasks when game part is changed
  for (i in 0:63) {
    game$tasks[[i]]$state       <-  0L
    game$tasks[[i]]$next_state  <-  0L
    game$tasks[[i]]$offset      <- -1L
    game$tasks[[i]]$next_offset <- -1L
    game$tasks[[i]]$stack       <- Stack$new()
  }
  
  # First task offset set to 0 to start it executing
  game$tasks[[0]]$offset <- 0
  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # initialise the game state
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  game$bytecode_offset    <- 0
  game$task_num           <- 0
  game$delay              <- 0
  game$paused             <- FALSE
  
  game$next_palette_idx    <- 1
  game$palette <- as_cindex( game$palette_collection[[game$next_palette_idx]] )
  
  game$current_page1   <- 2
  game$current_page2   <- 1
  game$current_page0   <- get_page(game, 0xfe)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup the main 'game' datastructure.
#
# TODO: make 'game' into an actual R6 class.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game <- new.env()
game$frame_count <- 0L
game$target_fps  <- 20
game$save_screenshots <- FALSE


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Initialise the 4 drawing devices used to render the game: MultiCanvas
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game$device <- MultiCanvasIndexedPalette$new(width = SCREEN_W, height = SCREEN_H)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Fetch next byte/word for the virtual machine from the current data
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game$read_byte <- read_byte_
game$read_word <- read_word_
environment(game$read_byte) <- game
environment(game$read_word) <- game


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup the 256 games variables a.k.a. the Virtual Machine registers
#
# Initial values for registers taken from another.js and Fabien's C code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vars_  <- numeric(256)     # 256 registers
vars_  <- as_cindex(vars_) # 0-indexed vector

# From Fabien
vars_[ 0x54 ] = 0x81

# From another.js
vars_[ 0xbc ] = 0x10
vars_[ 0xc6 ] = 0x80
vars_[ 0xf2 ] = 4000; # 4000 for Amiga bytecode
vars_[ 0xdc ] = 33
vars_[ 0xe4 ] = 20

game$vars <- vars_


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup the game task threads
# 
#  64 Tasks (a.k.a. threads)
#       - each task has a stack for current address when starting a new
#            subroutine call
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tasks_ <- lapply(seq(64), function(x) {
  list(
    id          = x - 1,
    offset      = -1,         # latest bytecode offset of this task
    next_offset = -1,         # where to restart this task
    state       =  0,
    next_state  =  0,
    stack       = Stack$new() # stack for return addresses from calls
  )
})

tasks_ <- as_cindex(tasks_) # 0-indexed vector

# Start the first task at address 0 in the bytecode
tasks_[[0]]$offset <- 0

game$tasks <- tasks_


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup Sound playback
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game$play_sounds <- TRUE
this_os <- detect_os()
if (this_os == 'mac') {
  play_sound <- play_sound_mac_afplay
} else if (this_os == 'unix') {
  message("play_sound_unix() not yet implemented. Help wanted! ")
  play_sound <- play_sound_unix
} else {
  message("Not a mac or unix system?  I will need some feedback to help figure out your system. No sound driver available. ")
  play_sound <- play_sound_null
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Given an 'event' object from 'eventloop::run_loop()' determine
# the current user action and write it into the input registers
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
update_input <- function(event) {
  mask = 0;

  if (is.null(event)) {
    game$vars[ VAR_HERO_POS_LEFT_RIGHT ] = 0;
    game$vars[ VAR_HERO_POS_JUMP_DOWN ] = 0;
    game$vars[ VAR_HERO_POS_UP_DOWN ] = 0;
    game$vars[ VAR_HERO_POS_MASK ] = 0;
    game$vars[ VAR_HERO_ACTION ] = 0;
    game$vars[ VAR_HERO_ACTION_POS_MASK ] = 0;
    return()
  }

  # if (event$type == 'key_press') {
  #   message(event$str)
  # }
  
  if (event$type == 'key_press' && event$str == 'Right') {
    game$vars[ VAR_HERO_POS_LEFT_RIGHT ] = 1;
    mask <- mask %|% 1;
  } else if (event$type == 'key_press' && event$str == 'Left') {
    game$vars[ VAR_HERO_POS_LEFT_RIGHT ] = -1;
    mask <- mask %|% 2;
  } else {
    game$vars[ VAR_HERO_POS_LEFT_RIGHT ] = 0;
  }
  if ( event$type == 'key_press' && event$str == 'Down' ) {
    game$vars[ VAR_HERO_POS_JUMP_DOWN ] = 1;
    game$vars[ VAR_HERO_POS_UP_DOWN ] = 1;
    mask <- mask %|% 4;
  } else if ( event$type == 'key_press' && event$str == 'Up' ) {
    game$vars[ VAR_HERO_POS_JUMP_DOWN ] = -1;
    game$vars[ VAR_HERO_POS_UP_DOWN ] = -1;
    mask <- mask %|% 8;
  } else {
    game$vars[ VAR_HERO_POS_JUMP_DOWN ] = 0;
    game$vars[ VAR_HERO_POS_UP_DOWN ] = 0;
  }
  game$vars[ VAR_HERO_POS_MASK ] = mask;
  if ( event$type == 'key_press' && event$str == ' ' ) {
    game$vars[ VAR_HERO_ACTION ] = 1;
    mask <- mask %|% 0x80;
  } else {
    game$vars[ VAR_HERO_ACTION ] = 0;
  }
  game$vars[ VAR_HERO_ACTION_POS_MASK ] = mask;
}







#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# This is the 'onIdle' even callback which actually runs the game
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
game_tick <- function(event, frame_num, event_env, ...) {

  # Use 'p' to pause the game
  if (!is.null(event) && event$type == 'key_press' && event$str == 'p') {
    game$paused <- !game$paused
    if (game$paused) {
      message("Game Paused")
    } else {
      message("Running ...")
    }
  }
  if (game$paused) {
    return()
  }

  # Keep a heartbeat message so I can know if the computer is actually
  # doing something or stuck in an infinite loop somewhere
  if (DEBUG && frame_num %% 500 == 0)
    mess("eventloop framenum = ", frame_num)

  for ( i in seq_along(game$tasks) - 1) {
    game$tasks[[ i ]]$state <- game$tasks[[ i ]]$next_state
    offset = game$tasks[[ i ]]$next_offset
    if ( offset != -1 ) {
      game$tasks[[ i ]]$offset = ifelse( offset == -2,  -1,  offset)
      game$tasks[[ i ]]$next_offset = -1
    }
  }
  update_input( event )
  
  found_valid_task <- FALSE
  for ( i in seq_along(game$tasks) - 1) {
    if ( game$tasks[[ i ]]$state == 0 ) {
      offset = game$tasks[[ i ]]$offset
      if ( offset != -1 ) {
        found_valid_task <- TRUE
        game$bytecode_offset <- offset
        game$tasks[[i]]$stack$reset()
        task_num    = i
        game$task_num <- task_num
        next_part <- execute_task(game = game, task_num = task_num)
        if (!is.null(next_part)) event_env$close <- next_part
        game$tasks[[i]]$offset = game$bytecode_offset
      }
    }
  }
  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # For some reason there are no valid tasks ready to run!
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (!found_valid_task) {
    cat("^!")
  }
  
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Initialise the output device and the MultiCanvas
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
display_scale <- 3


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setting the game parameters to start a particular section
#
# 16000  =  Protection    Not valid for this R version
# 16001  =  Introduction 
# 16002  =  Water        
# 16003  =  Jail         
# 16004  =  City         
# 16005  =  Arena        
# 16006  =  Luxe         
# 16007  =  Final        
# 16008  =  Password     Not valid for this R version
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PART <- ifelse(exists('PART'), PART, 16001)
init_game <- function(...) {
  load_part(PART)  #  <<<----------------------------------- Change this!
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# RUn the eventloop to play the game
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
eventloop::run_loop(
  user_func  = game_tick,
  init_func  = init_game,
  width      = SCREEN_W * display_scale/72,
  height     = SCREEN_H * display_scale/72,
  fps_target = 15,
  show_fps   = TRUE
)



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Manual frame rendering without an eventloop.  Works on windows.
#
# Windows does not support 'eventloop' because no R windows devices
# have been updated to support the 'onIdle' callback.  Help needed!
# So you can just run the introduction by rendering each frame in sequence
# with a a pause.  this won't work on other parts of the game because it
# will not process user input.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (FALSE) {
  x11(width = SCREEN_W * display_scale/72, height = SCREEN_H * display_scale/72, antialias = 'none', type = 'dbcairo')
  dev.control(displaylist = 'inhibit')
  
  load_part(16001)
  
  for (frame in seq(3000)) {
    dev.hold()
    game_tick(event = NULL, frame_num = frame)
    dev.flush()
    Sys.sleep(0.02)
  }

}





