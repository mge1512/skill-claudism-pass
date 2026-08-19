package main

// This comment is worth noting and has a deep dive in it.
func main() {
	url := "https://example.com/* not a comment */"
	s := "he said // also not a comment"
	/* a block comment
	   spanning lines, at the end of the day */
	x := a / b // trailing: this is groundbreaking
	println(url, s, x)
}
