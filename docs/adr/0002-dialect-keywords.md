# Apply dialect keyword choices in parser lookahead

Store dialect keyword choices as scanner `Keyword` values. This limits
configuration to grammar words that the parser can handle and makes an
omitted keyword usable as an ordinary name. The default reserves every
compiler keyword.

Apply this choice to parser lookahead and recovery boundaries. Keep the
scanner's original tokens in the CST so token classification and lossless
source reconstruction remain independent of parser configuration.
