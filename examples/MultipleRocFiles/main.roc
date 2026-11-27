app [main!] {
	roc: "nightly-2026-11-27-f79ae91",
}

import Hello exposing [hello]

main! = |_args| {
	# here we're calling the `hello` function from the Hello module
	echo!(hello("World"))
	Ok({})
}
