///|
priv suberror CliError {
  InvalidInput(String)
}

///|
impl Show for CliError with fn output(self, logger) {
  match self {
    InvalidInput(message) => logger.write_string(message)
  }
}

///|
async fn main {
  try {
    let command = @argparse.Command(
      "selene-xaml",
      about="Compile Selene XAML into typed MoonBit View packages.",
      version="selene-xaml 0.1.0",
      subcommand_required=true,
      disable_help_subcommand=true,
      subcommands=[
        @argparse.Command(
          "generate",
          about="Generate an Embedded View package.",
          flags=[
            @argparse.FlagArg(
              "dry-run",
              about="Generate and format without writing files.",
              action=@argparse.FlagAction::Count,
            ),
          ],
          options=[
            @argparse.OptionArg(
              "mbti",
              about="Use a MoonBit public interface contract.",
              required=true,
            ),
            @argparse.OptionArg(
              "out-dir",
              about="Set the generated package directory.",
              required=true,
            ),
          ],
          positionals=[
            @argparse.PositionArg(
              "view",
              about="XAML document to compile.",
              num_args=@argparse.ValueRange::single(),
            ),
          ],
        ),
      ],
    )
    let matches = command.parse()
    guard matches.subcommand is Some(("generate", request)) else {
      raise CliError::InvalidInput("generate command was not selected")
    }
    guard request.values.get("view") is Some([source]) else {
      raise CliError::InvalidInput("generate requires one XAML document")
    }
    guard request.values.get("out-dir") is Some([out_dir]) else {
      raise CliError::InvalidInput("generate requires --out-dir")
    }
    let dry_run_count = request.flag_counts.get("dry-run").unwrap_or(0)
    if dry_run_count > 1 {
      raise CliError::InvalidInput("duplicate generate option: --dry-run")
    }
    let dry_run = dry_run_count == 1
    guard request.values.get("mbti") is Some([mbti_path]) else {
      raise CliError::InvalidInput("generate requires --mbti")
    }
    let xaml = @fs.read_file(source).text()
    let mbti = @fs.read_file(mbti_path).text()
    let generated = @embedded_emitter.generate_embedded_view_package(
      source, xaml, mbti_path, mbti,
    )
    let generated = @embedded_emitter.format_generated_package(generated)
    if dry_run {
      let summary =
        $|would generate \{generated.files.length()} files in \{out_dir}
      println(summary)
      for file in generated.files {
        let output =
          $|  \{file.path}
        println(output)
      }
    } else {
      @embedded_emitter.commit_generated_package(out_dir, generated)
      let summary =
        $|generated \{generated.files.length()} files in \{out_dir}
      println(summary)
    }
  } catch {
    error => {
      @stdio.stderr.write(error.to_string().trim_end().to_owned() + "\n")
      @sys.exit(1)
    }
  }
}
