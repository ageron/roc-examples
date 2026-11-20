app [main!] {
	roc: "nightly-2026-11-19-54c51c9",
}

import "sample.txt" as sample : Str

main! = |_| {
	echo!("Contents of sample.txt: ${sample}\n")
	Ok({})
}
