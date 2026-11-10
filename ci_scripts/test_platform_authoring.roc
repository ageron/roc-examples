## Builds the PlatformAuthoring example, links it into the C, Zig and Rust hosts and
## checks that each host prints 42. Works on macOS, Linux and Windows.
##
## This script pins its own Roc version, so upgrading the example never waits on it.
## Run it from the repository root and pass the roc binary of the version the example pins:
##
##     roc ci_scripts/test_platform_authoring.roc EXAMPLE_ROC [c|zig|rust]...
##
## Without host names, all hosts are tested.
app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.27.0/9yjxqdGTP4xSpSEmDazwTmRsehfRZzA19pwEKkR6fj1g.tar.zst",
	roc: "nightly-2026-11-09-9e85de7",
}

import pf.Cmd
import pf.Env
import pf.OsStr
import pf.Path
import pf.Stdout
import pf.System

main! : List(OsStr) => Try({}, _)
main! = |args| {
	(roc, hosts) =
		match args {
			[] => return Err(Usage("roc ci_scripts/test_platform_authoring.roc EXAMPLE_ROC [c|zig|rust]..."))
			[roc_arg] => (roc_arg, [C, Zig, Rust])
			[roc_arg, .. as names] => (roc_arg, names.map_try(parse_host)?)
		}

	target = System.target!()
	os =
		match target.os() {
			Linux(_) => Linux
			MacOS(_) => MacOS
			Windows(_) => Windows
		}
	arch =
		match target.arch() {
			X64 => "x86_64"
			Arm64 => "aarch64"
		}

	example = Path.absolute!("examples/PlatformAuthoring")?
	main_roc = example.join("main.roc").to_os_str()

	run!(Cmd.new(roc).args(["test", "--no-cache", main_roc]))?

	Env.with_temp_dir!(
		|work| {
			# Roc's Windows targets produce an MSVC static library.
			archive = if (os == Windows) "app.lib" else "app.a"
			archive_path = work.join(archive).to_str()?
			run!(Cmd.new(roc).args(["build", "--no-cache", main_roc, "--output=${archive_path}"]))?

			for host in hosts {
				exe = exe_name(host, os)
				run!(link_cmd(host, os, arch, example, archive, exe).cwd(work))?

				output = Cmd.new(work.join(exe).to_os_str()).capture!()?
				# trim, C's printf ends the line with \r\n on Windows.
				if output.trim() != "42" {
					return Err(UnexpectedOutput({ host: exe, output }))
				}
				Stdout.line!("${exe}: printed 42 and exited successfully")?
			}

			Ok({})
		},
	)
}

parse_host : OsStr -> Try([C, Zig, Rust], [UnknownHost(Str)])
parse_host = |arg|
	if arg == "c" {
		Ok(C)
	} else if arg == "zig" {
		Ok(Zig)
	} else if arg == "rust" {
		Ok(Rust)
	} else {
		Err(UnknownHost(arg.display()))
	}

exe_name : [C, Zig, Rust], [Linux, MacOS, Windows] -> Str
exe_name = |host, os| {
	name =
		match host {
			C => "host-c"
			Zig => "host-zig"
			Rust => "host-rust"
		}

	if (os == Windows) "${name}.exe" else name
}

## The command that links the Roc archive into a host, run in the directory of the archive.
link_cmd : [C, Zig, Rust], [Linux, MacOS, Windows], Str, Path, Str, Str -> Cmd.Command
link_cmd = |host, os, arch, example, archive, exe| {
	# Roc's static archive contains non-PIC code. Linux hosts must link a non-PIE
	# executable, even when the distribution defaults to PIE.
	linux = os == Linux

	match host {
		C if os == Windows =>
			Cmd.new("cl").args(["/nologo", "/std:c11", example.join("host.c").to_os_str(), "${archive}", "/Fe${exe}"])

		C =>
			Cmd.new("cc")
				.args(["-std=c11", example.join("host.c").to_os_str(), "${archive}", "-lm", "-o", "${exe}"])
				.args(if (linux) ["-no-pie"] else [])

		Zig =>
			Cmd.new("zig")
				.args(["build-exe", example.join("host.zig").to_os_str(), "${archive}", "-lc", "-femit-bin=${exe}"])
				.args(if (linux) ["-fno-PIE"] else [])
				# Match Zig's ABI to the MSVC archive.
				.args(if (os == Windows) ["-target", "${arch}-windows-msvc"] else [])

		Rust =>
			Cmd.new("rustc")
				.args(["--edition=2024", example.join("host.rs").to_os_str(), "-C", "link-arg=${archive}", "-o", "${exe}"])
				.args(if (linux) ["-C", "relocation-model=static"] else [])
	}
}

## Prints a command, then runs it and requires it to succeed.
run! : Cmd.Command => Try({}, _)
run! = |cmd| {
	Stdout.line!("+ ${cmd.to_str()}")?
	cmd.call!()
}
