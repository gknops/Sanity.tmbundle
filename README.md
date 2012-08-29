# Introduction

TextMate2's typing pairs are a nice touch in theory. But more often than not I found myself deleting the inserted right half, or cursing because a complex regular expression broke due to a stray auto-inserted right half.

Similarly I found myself fighting TextMate2's idea of indent correction. And after trying to make them work reasonable for way to long, I decided it was time to cut the cord, disable it and roll my own.

Rules:
- Do not modify the line I am working on. Assume I adjusted the indentation as I wanted it.
- Any automatic stuff should happen in the newly inserted rows only.
- I still would like the benefit of the auto-closed block/parenthesis etc.

So I came up with with *Sanity.tmbundle*, handling indentations in a way to keep those of us fighting the TextMate-native indent correction sane.

Generally for each language Sanity supports it does:

- Disable Indent Correction.
- Disable Smart Typing Pairs. If you like it, you can re-enable it, *Sanity* should handle that fine.
- Perform automatic actions when the return key is pressed.

These automatic actions are:

- If there are any dangling open pairs, insert the matching closing half.
- Move the cursor to a reasonable position.

For good measure, also recognize more complex pairs such as if/fi, case/esac, <div xxxx></div> etc.

Examples (`|` denotes the cursor before and after):

### C-Like

	{|

becomes

	{
		|
	}

### Shell


	if [ -f "$path" ]; then|

becomes

	if [ -f "$path" ]; then
		|
	fi

### HTML, XML

	<table key+"val">|

becomes

	<table key+"val">
		|
	</table>

