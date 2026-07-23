# CLI process contract

`CG-GENERATE-02` verifies that the CLI definition requires an Embedded View
business contract.

```mooncram {output_stream: stderr}
$ selene-xaml generate your_game/ui/inventory.xaml \
>   --out-dir your_game/src/view
error: the following required argument was not provided: 'mbti'

Usage: selene-xaml generate --mbti <mbti> --out-dir <out-dir> [options] <view>

Generate an Embedded View package.

Arguments:
  view  XAML document to compile.

Options:
  -h, --help           Show help information.
  --dry-run            Generate and format without writing files.
  --mbti <mbti>        Use a MoonBit public interface contract.
  --out-dir <out-dir>  Set the generated package directory.
[1]
```

```mooncram {output_stream: stderr}
$ selene-xaml generate your_game/ui/inventory.xaml \
>   --mbti your_game/src/model/pkg.generated.mbti \
>   --out-dir your_game/src/view \
>   --dry-run --dry-run
duplicate generate option: --dry-run
[1]
```

`CG-GENERATE-06` also verifies that a failed command leaves stdout empty. The
user-facing stderr transcript lives in `docs/cli/README.md`.

```mooncram {output_stream: stdout}
$ selene-xaml
[1]
```

`CG-GENERATE-07` verifies that dry-run completes the generator pipeline without
creating its requested output directory.

```mooncram
$ selene-xaml generate your_game/ui/inventory.xaml \
>   --mbti your_game/src/model/pkg.generated.mbti \
>   --out-dir your_game/src/dry_run_view \
>   --dry-run > /dev/null && \
>   test ! -e your_game/src/dry_run_view
```
