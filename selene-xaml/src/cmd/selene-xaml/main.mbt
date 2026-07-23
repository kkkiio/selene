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
          about="Generate an Embedded View or Component Guest package.",
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
            ),
            @argparse.OptionArg(
              "wit",
              about="Use a WIT file or directory contract.",
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
          groups=[
            @argparse.ArgGroup("contract", required=true, multiple=false, args=[
              "mbti", "wit",
            ]),
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
    let mbti = request.values.get("mbti").map(values => values[0])
    let wit = request.values.get("wit").map(values => values[0])
    match (mbti, wit) {
      (None, Some(path)) => {
        let wit_files : Array[String] = match @fs.kind(path) {
          @fs.FileKind::Directory =>
            @fs.readdir(path, sort=true)
            .filter(name => name.has_suffix(".wit"))
            .map(name => path + "/" + name)
          @fs.FileKind::Regular => [path]
          _ =>
            raise CliError::InvalidInput(
              "--wit must name a WIT file or directory: " + path,
            )
        }
        if wit_files.length() == 0 {
          raise CliError::InvalidInput(
            "--wit directory contains no .wit files: " + path,
          )
        }
        let wit_source = StringBuilder::new()
        for wit_file in wit_files {
          wit_source <+ "\{@fs.read_file(wit_file).text()}"
          wit_source <+ "\n"
        }
        let xaml = @fs.read_file(source).text()
        let generated = @codegen.generate_component_guest_package(
          source,
          xaml,
          path,
          wit_source.to_string(),
        )
        let generated = @generator_io.format_generated_package(generated)
        if dry_run {
          let summary =
            $|would generate \{generated.files.length()} Component Guest files in \{out_dir}
          println(summary)
          for file in generated.files {
            let output =
              $|  \{file.path}
            println(output)
          }
        } else {
          @generator_io.commit_generated_package(out_dir, generated)
          let summary =
            $|generated \{generated.files.length()} Component Guest files in \{out_dir}
          println(summary)
        }
      }
      (Some(mbti_path), None) => {
        let xaml = @fs.read_file(source).text()
        let mbti = @fs.read_file(mbti_path).text()
        let generated = @codegen.generate_embedded_view_package(
          source, xaml, mbti_path, mbti,
        )
        let generated = @generator_io.format_generated_package(generated)
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
          @generator_io.commit_generated_package(out_dir, generated)
          let summary =
            $|generated \{generated.files.length()} files in \{out_dir}
          println(summary)
        }
      }
      _ => raise CliError::InvalidInput("generate requires one contract")
    }
  } catch {
    error => {
      @stdio.stderr.write(error.to_string().trim_end().to_owned() + "\n")
      @sys.exit(1)
    }
  }
}
