# Run with `roc ./examples/CommandLineArgs/main.roc -- examples/CommandLineArgs/input.txt`
app "command-line-args"
    packages {
        pf: "../../../basic-cli/platform/main.roc",
    }
    imports [
        pf.Stdout,
        pf.File,
        pf.Path,
        pf.Task,
        pf.Arg,
    ]
    provides [main] to pf

main =
    finalTask =
        # try to read the first command line argument
        pathArg = readFirstArgT!

        readFileToStr (Path.fromStr pathArg)

    finalResult <- Task.attempt finalTask

    when finalResult is
        Err ZeroArgsGiven ->
            Task.err (Exit 1 "Error ZeroArgsGiven:\n\tI expected one argument, but I got none.\n\tRun the app like this: `roc command-line-args.roc -- path/to/input.txt`")

        Err (ReadFileErr errMsg) ->
            indentedErrMsg = indentLines errMsg

            Task.err (Exit 1 "Error ReadFileErr:\n$(indentedErrMsg)")

        Ok fileContentStr ->
            Stdout.line "file content: $(fileContentStr)"

# Task to read the first CLI arg (= Str)
readFirstArgT : Task.Task Str [ZeroArgsGiven]_
readFirstArgT =
    # read all command line arguments
    args = Arg.list!

    # get the second argument, the first is the executable's path
    List.get args 1 |> Result.mapErr (\_ -> ZeroArgsGiven) |> Task.fromResult

# reads a file and puts all lines in one Str
readFileToStr : Path.Path -> Task.Task Str [ReadFileErr Str]_
readFileToStr = \path ->
    path
    |> File.readUtf8 # Make a nice error message
    |> Task.mapErr
        (\fileReadErr ->
            pathStr = Path.display path
            # TODO use FileReadErrToErrMsg when it is implemented: https://github.com/roc-lang/basic-cli/issues/44
            when fileReadErr is
                FileReadErr _ readErr ->
                    readErrStr = File.readErrToStr readErr
                    ReadFileErr "Failed to read file at:\n\t$(pathStr)\n$(readErrStr)"

                FileReadUtf8Err _ _ ->
                    ReadFileErr "I could not read the file:\n\t$(pathStr)\nIt contains charcaters that are not valid UTF-8:\n\t- Check if the file is encoded using a different format and convert it to UTF-8.\n\t- Check if the file is corrupted.\n\t- Find the characters that are not valid UTF-8 and fix or remove them."
        )

# indent all lines in a Str with a single tab
indentLines : Str -> Str
indentLines = \inputStr ->
    Str.split inputStr "\n"
    |> List.map (\line -> Str.concat "\t" line)
    |> Str.joinWith "\n"
