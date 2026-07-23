  $ repo_root="$TESTDIR/../.."
  $ mkdir -p your_game/ui your_game/src/model your_game/wit
  $ cp "$repo_root/examples/inventory/inventory.xaml" your_game/ui/inventory.xaml
  $ cp "$repo_root/examples/inventory/src/model/pkg.generated.mbti" your_game/src/model/pkg.generated.mbti
  $ cp "$repo_root/fixtures/component-emitter/demo.xaml" your_game/ui/component.xaml
  $ cp "$repo_root/fixtures/component-emitter/"*.wit your_game/wit/
  $ selene-xaml() { selene-xaml.exe "$@"; }
