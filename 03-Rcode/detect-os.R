


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Simple code to detect OS. It's pretty naive, but works for now.
# Is there a function for this in base R?
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
detect_os <- function(){
  sysname <- Sys.info()[['sysname']]
  if (sysname == 'Darwin') {
    'mac'
  } else if (.Platform == 'windows') {
    'windows'
  } else {
    'unix'
  }
}
