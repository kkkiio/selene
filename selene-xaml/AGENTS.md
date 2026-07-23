# AGENTS.md

## Domain Language

- **Infoset** — XAML parser 与 compiler 使用的 schema、对象、成员、文本、诊断和 source span 语义数据模型。
- **ViewIR** — compiler 从 Infoset 与业务 contract lower 得到的 typed intermediate representation；包含 UI tree、binding、reconciliation 和 action route，由 Embedded emitter 与 Component emitter 分别生成独立 runtime source。
- **UI mutation** — Generated View 或 Component Guest 对 Selene UI 的增量修改；包含 mount、精确属性更新、move 和 remove，并由 Selene UI Host 原子验证和提交。
- **Selene UI Host** — Embedded 与 Component 共用的进程内 concrete UI mutation 提交器；管理 mounted Entity hierarchy、Selene UI stores、focus、scroll 和 raw UI event route。
- **Embedded View package** — 由 Embedded emitter 生成、被 MoonBit 游戏项目直接 import 的 package；公开 API 以 Selene Entity 为 mounted View 身份，并静态调用 Selene UI Host。
- **Component Guest package** — 由 Component emitter 独立生成并编译为 `.component.wasm` 的 MoonBit package；接收 Host 传入的 Entity UInt，并在 Guest memory 中以它为 key 保存 model、computed ViewModel、reconciliation 和 action route。
- **Component Guest record** — Component Guest package 的私有 View state；一个 Component instance 绑定一个 Selene World，因此 record key 只需要该 World 内单调递增的 Entity UInt。
- **Component Host** — 完整的 Wasm Host 集成；负责 loader/runtime、业务 WIT bindings、Component instance 与 World 绑定、Entity lifetime 和 UI Host WIT imports，并把 Guest UI mutation 交给 Selene UI Host。

## Policies & Mandatory Rules

### Compatibility Policy

当修改公开 API、持久化数据、配置文件、CLI 参数、plugin/WIT contract 或用户工作流时：

- 将项目和第一方 contract 视为 `0.x`，在明确采用稳定版 policy 前不保证 source、binary 或 data compatibility。
- 优先直接迁移和简洁的当前实现；除非用户明确要求，不添加兼容层、deprecated alias、双版本 adapter 或 legacy fallback。
- 在同一变更中同步所有仓库内调用方、fixture、generated artifact、ABI fingerprint 和文档。
- 第一方 WIT package version 跟随项目 release version；不要因 `0.x` 阶段的内部 ABI 变更推导 major version bump。
- 在最终回复中说明有意的 breaking change；仅当仓库已有 `CHANGELOG.md` 或 release notes 时同步记录。

### Profile Policy

同步 `docs/ms-xaml-conformance.md` 中的行为、偏差和自动化测试 ID。

使用 `x:` namespace 表示标准 directive，使用 `urn:selene:xaml:ui` 表示 Selene vocabulary。

### API Boundary Policy

仅在真实业务调用方需要查询能力时新增 API；不为测试暴露 View、Host adapter 或 interpreter 的私有 record、system 或 opaque handle 字段。

### MoonBit Code Policy

生成或拼接多行文本时，静态内容使用 `#|`、插值内容使用 `$|`，向 builder 写入模板时使用 `<+`，避免 `write_string` 与字符串 `+` 链。

### Test Policy

- 默认编写黑盒 `*_test.mbt`，通过公开 package API、`App` 和 `plugin` 驱动行为。
- 快照 parser infoset、诊断、typed mutation batch、公开 action/lifecycle，以及 Host adapter 的公开 ECS 层级和 Selene UI stores。

仅修改文档且不改变行为时，可以跳过 `$write-snapshot-test`。

## Project Structure Guide

### Repo Structure & Important Files

```text
.
├── AGENTS.md                         # Agent 开发与验证规则
├── README.md                         # 用户安装与使用说明
├── justfile                          # fmt、check、test、test-all 与 example capture 入口
├── .github/workflows/ci.yml           # PR/main 日常测试与 examples 编译
├── docs/
│   ├── ms-xaml-conformance.md         # Profile 1 规范覆盖与测试 ID
│   ├── selene-xaml-vocabulary.md      # Selene vocabulary 定义、生态对比与设计取舍
│   ├── selene-css-layout.md           # CSS Flexbox/Grid 布局 vocabulary
│   └── engineering/                  # generated View API、Wasm 与 Host 决策
├── fixtures/                         # XAML conformance fixtures
├── examples/
│   ├── inventory/                    # 精简的 Inventory JS/Web showcase
│   ├── survivors/                    # 精简的 Survivors JS/Web showcase
│   └── wasm-component/               # Component Guest、独立 Selene Host 与 browser showcase
├── runtime/                           # KKKIIO/selene_xaml_runtime module；不依赖 compiler/XML
│   └── src/
│       ├── ui_host/                   # Embedded 与 Component 共用的 UI mutation values
│       ├── view_runtime/              # generated View reconcile、transaction 与 action routing
│       ├── component_host/            # Selene UI Host、browser WIT bridge 与 CH-* tests
│       └── component_loader/          # native Wasmtime loader FFI
├── tests/
│   ├── target-matrix/                # View、布局与 Component loader 的跨 target 语义矩阵
│   ├── browser/                      # Playwright readiness 与 screenshot harness
│   └── wasm-components/              # Component 跨 target 回归说明
└── src/
    ├── infoset/
    │   ├── moon.pkg
    │   ├── types.mbt                 # XamlDocument、XamlData、XamlError
    │   └── schema.mbt                # XamlSchema 与 schema registry
    ├── parser/
    │   ├── moon.pkg
    │   ├── aliases.mbt               # 私有 infoset imports
    │   ├── markup.mbt                # Markup extension parser
    │   ├── parser.mbt                # XAML object mapping
    │   └── parser_test.mbt            # PC-* 黑盒测试
    ├── viewir/                        # Infoset + business contract → sealed typed ViewIR
    ├── codegen/                       # 共享 MoonBit source 生成工具，供 *_emitter 使用
    ├── embedded_emitter/              # Embedded View package MoonBit source 生成
    ├── component_emitter/             # Component Guest package WIT + MoonBit source 生成
    ├── cmd/selene-xaml/               # native generate/check CLI
    └── generator_io/                  # generated package 原子更新与 ownership file list
```

## Operation Guide

### Format and Check

从 repository root 运行：

```bash
just fmt
just check
```

### Tests

运行日常语义回归：

```bash
just test
```

编译 Inventory、Survivors、Wasm Component Guest 和独立 browser Host：

```bash
just build-examples
```

运行 JS/native、Wasm Component、native loader 与 browser 的完整矩阵：

```bash
just test-all
```

### Generate a View Package

重新生成 `examples/inventory/src/view` 或 `examples/survivors/src/view` 时，提交
generator 拥有的 `moon.pkg`、`state.generated.mbt`、`view.generated.mbt`、
`view.generated.mbt.map.json` 和 `selene-xaml.lock.json`；将第一方示例的 source map
作为 generator regression snapshot 审查。下游游戏项目自行决定是否提交
`*.mbt.map.json`。

```bash
just generate-examples
```

### Generated Interfaces

当公开 API 发生变化时，更新并审查 tracked `.mbti` 文件：

```bash
moon info -p KKKIIO/selene_xaml --target all
moon -C runtime info -p KKKIIO/selene_xaml_runtime --target all
```
