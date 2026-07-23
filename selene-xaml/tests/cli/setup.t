  $ workspace_root="$TESTDIR/../../.."
  $ mkdir -p your_game/ui your_game/src/model
  $ cp "$workspace_root/examples/inventory/inventory.xaml" your_game/ui/inventory.xaml
  $ cp "$workspace_root/examples/inventory/model/pkg.generated.mbti" your_game/src/model/pkg.generated.mbti
  $ selene-xaml() { selene-xaml.exe "$@"; }
