# AGENTS.md

## Domain Language

- **Infoset** — XAML parser 与 compiler 使用的 schema、对象、成员、文本、诊断和 source span 语义数据模型。
- **ViewIR** — compiler 从 Infoset 与 MoonBit 业务 contract lower 得到的 typed intermediate representation。
- **UI mutation** — Generated View 对 Selene UI 的增量修改，包含 mount、精确属性更新、move 和 remove。
- **Selene UI View** — `../selene-core/src/ui_view` 中的进程内 UI mutation runtime，管理 Entity hierarchy、UI stores、focus、scroll 和 raw event route。
- **Embedded View package** — 由 Embedded emitter 生成并被 MoonBit 游戏直接 import 的 package；公开 API 以 Selene Entity 为 mounted View 身份。
- **Generated package** — generator 拥有的 `moon.pkg`、MoonBit source、source map 和 `selene-xaml.lock.json` 文件集合。

## Policies & Mandatory Rules

### Compatibility Policy

修改公开 API、配置文件、CLI 参数或用户工作流时：

- 将项目视为 `0.x`，在明确采用稳定版 policy 前不保证 source 或 data compatibility。
- 采用直接迁移和简洁的当前实现；除非用户明确要求，不添加兼容层、deprecated alias 或 legacy fallback。
- 在同一变更中同步仓库内调用方、fixture、generated artifact、ABI fingerprint 和文档。
- 在最终回复中说明有意的 breaking change，并同步更新上层仓库的 `docs/CHANGELOG.md`。

### Documentation Intent Principle

文档记录意图，代码实现意图。意图是 source of truth。

- 行为意图变化时，先更新 `docs/engineering/` 中对应的 living document。
- 只记录当前方案；意图变化时直接更新或删除过期文档，让 Git 保存历史。
- 将用户安装和使用说明放在 `README.md`，将修改仓库所需的约束与命令放在本文件。

### Profile Policy

修改 XAML 语义、vocabulary 或诊断时，同步 `docs/ms-xaml-conformance.md` 中的行为、偏差和自动化测试 ID。

使用 `x:` namespace 表示标准 directive，使用 `urn:selene:xaml:ui` 表示 Selene vocabulary。

### API Boundary Policy

仅在真实业务调用方需要查询能力时新增 API；不为测试暴露 View、Host adapter 或 interpreter 的私有 record、system 或 opaque handle 字段。

### MoonBit Code Policy

生成或拼接多行文本时，静态内容使用 `#|`、插值内容使用 `$|`，向 builder 写入模板时使用 `<+`，避免 `write_string` 与字符串 `+` 链。

### Test Policy

修改 `src/`、`../selene-core/src/ui_view/`、generated package 或语义测试时，运行 `$write-snapshot-test`。

- 默认编写黑盒 `*_test.mbt`，通过公开 package API、`App` 和 `plugin` 驱动行为。
- 快照 parser infoset、诊断、typed mutation batch、公开 action/lifecycle，以及 View Host 的公开 ECS 层级和 Selene UI stores。
- 通过 `moon test --update` 或 `moon cram test --update` 更新工具生成的快照，再审查差异。
- 仅修改文档且不改变行为时，跳过 `$write-snapshot-test`。

## Project Structure Guide

### Repo Structure & Important Files

```text
.
├── AGENTS.md                         # Agent 开发与验证规则
├── README.md                         # 用户安装与使用说明
├── justfile                          # fmt、check、test、test-all 与 example 入口
├── .github/workflows/ci.yml          # PR/main 测试与 examples 编译
├── docs/
│   ├── cli/                          # CLI 可执行 contract 与 cram 文档测试
│   ├── engineering/                  # compiler、generated View 与 runtime 的当前意图
│   ├── ms-xaml-conformance.md        # Profile 1 规范覆盖与测试 ID
│   └── selene-xaml-vocabulary.md     # Selene vocabulary 定义
├── fixtures/                         # XAML conformance 与 emitter fixtures
├── examples/
│   └── survivors/                    # Survivors Embedded View showcase
├── tests/
│   ├── browser/                      # Embedded View examples 的 Playwright readiness harness
│   ├── cli/                          # CLI process contract
│   └── target-matrix/                # View 与布局的 JS/native 语义矩阵
├── src/
│   ├── infoset/                      # XAML semantic data model
│   ├── parser/                       # XML/XAML object mapping 与 PC-* tests
│   ├── viewir/                       # Infoset + `.mbti` contract → sealed typed ViewIR
│   ├── embedded_emitter/             # package emission、格式化、原子更新与 ownership lock
│   └── cmd/selene-xaml/              # native `generate` CLI
├── ../examples/inventory/            # Inventory model、XAML、generated View 与共享运行逻辑
├── ../examples-web/inventory/web/    # Inventory WebGPU launcher
└── ../selene-core/src/ui_view/       # ViewHost、mutation values 与 VH-* tests
```

## Operation Guide

### Format and Check

从 `selene-xaml/` 运行：

```bash
just fmt
just check
```

### Tests

运行日常语义回归：

```bash
just test
```

编译 Inventory 与 Survivors Embedded View examples：

```bash
just build-examples
```

运行 JS/native 与 browser 完整矩阵：

```bash
just test-all
```

### Generate a View Package

重新生成 `../examples/inventory/view` 和 `examples/survivors/src/view`：

```bash
just generate-examples
```

提交 generator 拥有的 `moon.pkg`、`state.generated.mbt`、`view.generated.mbt`、
`view.generated.mbt.map.json` 和 `selene-xaml.lock.json`，并审查 source map 与 ownership hash。

### Generated Interfaces

公开 API 变化时更新并审查 tracked `.mbti`：

```bash
moon info -p KKKIIO/selene_xaml --target all
moon -C ../selene-core info src/ui_view --target all
```
