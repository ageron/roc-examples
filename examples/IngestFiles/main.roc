app [main!] {
	roc: "nightly-2026-11-13-03dce41",
}

import "sample.txt" as sample : Str

main! = |_| {
	echo!("Contents of sample.txt: ${sample}\n")
	Ok({})
}
