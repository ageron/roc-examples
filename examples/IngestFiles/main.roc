app [main!] {
	roc: "nightly-2026-11-27-f79ae91",
}

import "sample.txt" as sample : Str

main! = |_| {
	echo!("Contents of sample.txt: ${sample}\n")
	Ok({})
}
