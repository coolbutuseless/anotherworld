
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zero-based indexing for atomic vectors and lists
# Idea stolen from {index0} package and extended for list indexes
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
as_cindex <- function (x) {
  class(x) <- union(class(x), "cindex")
  x
}

`[.cindex` <- function (x, i, ...)  {
  i <- i + 1
  as_cindex(NextMethod())
}

`[<-.cindex` <- function (x, i, ..., value) {
  i <- i + 1
  as_cindex(NextMethod())
}

`[[.cindex` <- function (x, i, ...)  {
  i <- i + 1L
  NextMethod()
}

`[[<-.cindex` <- function (x, i, ..., value) {
  i <- i + 1L
  NextMethod()
}

head.cindex <- function(x, n = 6L, ...) {
  x[seq(n) - 1]
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# bitwise ops on integers
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'%&%'  <- function(x, y) bitwAnd   (x, y)
'%|%'  <- function(x, y) bitwOr    (x, y)
'%<<%' <- function(x, y) bitwShiftL(x, y)
'%>>%' <- function(x, y) bitwShiftR(x, y)