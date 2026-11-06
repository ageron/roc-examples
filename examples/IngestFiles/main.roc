app [main!] {
	roc: "nightly-2026-11-06-34f137a",
}

import "sample.txt" as sample : Str

main! = |_| {
	echo!("Contents of sample.txt: ${sample}\n")
	Ok({})
}
