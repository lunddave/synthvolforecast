\name{dbw}
\alias{dbw}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
A function that carries out distance-based weighting.
}
\description{
A function that carries out distance-based weighting.}

\usage{
dbw(X, dbw_indices, shock_time_vec, scale = FALSE, center = FALSE, sum_to_1 = 1, bounded_below_by = 0, bounded_above_by = 1, normchoice = c("l1", "l2")[2], penalty_normchoice = c("l1", "l2")[1], penalty_lambda = 0)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{X}{
%%     ~~Describe \code{X} here~~
}
  \item{dbw_indices}{
%%     ~~Describe \code{dbw_indices} here~~
}
  \item{shock_time_vec}{
%%     ~~Describe \code{shock_time_vec} here~~
}
  \item{scale}{
%%     ~~Describe \code{scale} here~~
}
  \item{center}{
%%     ~~Describe \code{center} here~~
}
  \item{sum_to_1}{
%%     ~~Describe \code{sum_to_1} here~~
}
  \item{bounded_below_by}{
%%     ~~Describe \code{bounded_below_by} here~~
}
  \item{bounded_above_by}{
%%     ~~Describe \code{bounded_above_by} here~~
}
  \item{normchoice}{
%%     ~~Describe \code{normchoice} here~~
}
  \item{penalty_normchoice}{
%%     ~~Describe \code{penalty_normchoice} here~~
}
  \item{penalty_lambda}{
%%     ~~Describe \code{penalty_lambda} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}

\examples{
##---- Should be DIRECTLY executable !! ----
##-- ==>  Define data, use random,
##--	or do  help(data=index)  for the standard data sets.
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory (show via RShowDoc("KEYWORDS")):
% \keyword{ ~kwd1 }
% \keyword{ ~kwd2 }
% Use only one keyword per line.
% For non-standard keywords, use \concept instead of \keyword:
% \concept{ ~cpt1 }
% \concept{ ~cpt2 }
% Use only one concept per line.
