#!/bin/bash
# A shell comment that is cutting-edge.
cat <<EOF
This heredoc body # is not a comment and mentions a tapestry
EOF
cat <<-'QUOT'
	indented terminator, # still not a comment
	QUOT
n="${#files[@]}"   # ${#...} must not open a comment
