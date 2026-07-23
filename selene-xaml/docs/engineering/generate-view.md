# Generate Command

本文定义 `selene-xaml generate` 的输入、输出、generated source ownership、确定性与
diagnostic source mapping。

## 决策

发布可通过 `moon install` 安装的 native `selene-xaml` CLI。应用仓库显式运行
generator 并提交 generated source 与 ownership lock。Selene XAML 仓库提交第一方示例的
source map 作为 generator regression snapshot；下游应用自行选择是否提交 source map。

generator 原子生成一个 typed package，不依赖 dependency package pre-build
执行任意命令。`.mbti` 选择 Embedded emitter，WIT 选择 Component
emitter；每次 invocation 只生成一种 package，两种产物使用独立的 output
directory 和 ownership lock。

## 分发

CLI 是 native executable，与 `infoset`、`parser`、`codegen` library packages 保持在同一个
module 中原子发布；
backend 差异由 package-level `supported_targets` 表达。module 级 JS/Wasm 检查会跳过
native-only CLI，并继续检查其余可达 library package。CLI 使用 `moonbitlang/async` 的
native 文件 I/O，命令行参数来自 `moonbitlang/core/env`。

`KKKIIO/selene_xaml_runtime` 是独立 module，包含 Embedded 与 Component 共用的 Selene UI Host、
Component Host loader 所需的 `ui_host`、`component_host`、`component_loader` 和共享 runtime
package。应用的
`moon.work` 只需要包含该 runtime module，不需要把 compiler module 及其
`Milky2018/xml@0.4.0` parser 依赖带入应用 workspace。

CLI 通过 `moon install` 按明确版本安装。

generated lock 记录 generator 版本、输入 contract 和各 generated file 的 ownership。

## CLI 命令面

生成可被 MoonBit 游戏直接 import 的 Embedded View package：

```text
selene-xaml generate <view.xaml> --mbti <model.mbti> --out-dir <view-package-dir>
```

WIT 选择独立的 WebAssembly Component Guest package：

```text
selene-xaml generate <view.xaml> --wit <wit-file-or-dir> --out-dir <component-guest-package-dir>
```

`--mbti` 与 `--wit` 必须且只能提供一个。`--out-dir` 的含义由
contract kind 确定：Embedded View package directory 或 Component Guest package
directory。`selene-xaml` 不运行 `wit-bindgen`、Moon build、`wasm-tools` 或 `jco`。

`--dry-run` 执行读取、解析、ViewIR lowering、emission 和格式化，向 stdout 输出将生成的
完整文件集合，不创建或修改 `--out-dir`。它用于验证完整 generation request；实际提交仍由不带
`--dry-run` 的同一命令执行。

存在多个 WIT world、exported business interface 或 XAML document 时，命令增加明确、可重复的
`--world`、`--interface` 或 `--view` selector。没有歧义时禁止要求这些参数。CLI 不接受内嵌
MoonBit expression、JSON expression map、generator manifest 或 component manifest。

stdout 只输出请求结果，diagnostics 写 stderr，失败返回非零退出码。

## Input 与 lock 边界

XAML、WIT、MoonBit source 和派生 `.mbti` 是 source input。用户不维护 generator manifest 或
component manifest；world、business interface、state/patch/action mapping、package alias 和 output naming
由 source 与明确 selector 推导。多个 world、interface 或 XAML document 存在歧义时，CLI 要求
可重复的 selector。

`selene-xaml.lock.json` 是 generated ownership record，包含 source URI 与 hash、resolved
contract、requested outputs、output naming、package alias、imported sidecars、Host capability 和 ABI
fingerprint。Output hash 描述本次生成结果，不用于阻止覆盖已登记的 generated file。它不包含
parsed Infoset、interpreter object tree、binding descriptor、字符串 property table 或未由
`selene-xaml` 执行的外部构建工具版本。

## Generate outputs

`.mbti` generation 的 output 是 Embedded View package：

```text
<view-package-dir>/
├── moon.pkg
├── state.generated.mbt
├── view.generated.mbt
├── view.generated.mbt.map.json
└── selene-xaml.lock.json
```

业务 Model 和 `compute_view_model` 由 `.mbti` 所属 package 拥有。Generated
package 通过 import/type alias 引用它们，不复制 nominal business type。Output
directory 中其他用户 source 会被保留，generator 只拥有 lock 记录的文件。

WIT generation 的 output 是 Component Guest package source：

```text
<component-guest-package-dir>/
├── guest.generated.mbt
├── guest.generated.mbt.map.json
└── selene-xaml.lock.json
```

Component output directory 通常同时包含由 `wit-bindgen` 拥有的 bindings
和用户 source。`moon.pkg` 由 Component project 拥有，负责 import 生成的
WIT bindings。Generator 只更新 lock 中声明的 source/source-map 文件。
`.component.wasm`、browser bundle 和其他 release artifact 不属于 `generate` output。

## Generated artifact policy

| artifact | 是否提交 | 用途 |
| --- | --- | --- |
| business package `.mbti` | 按 Moon package policy | embedded generator 的派生公开类型输入，不手写 |
| `.generated.mbt` | 是 | Embedded View 或 Component Guest source，供 review 与下游构建 |
| `.mbt.map.json` | 第一方示例提交，下游自定 | Moon diagnostic -> XAML source span；本仓库同时将其作为 generator regression snapshot |
| component interface sidecar | 是 | 跨 package 构建期 typed component ABI |
generated source 由工具拥有；人工修改会在下一次生成时被覆盖。

## Moon build rule 约束

Moon `rule`/`dev_build` 当前只声明单个 `input` 与 `output`，dependency package 的
pre-build 不会在下游自动执行。因此：

1. `just generate-xaml` 显式调用已 pin generator；
2. `just check`/CI 运行 Moon checks 与 generated package 验收测试；
3. 单 XAML/单 output package 可额外用 `dev_build` 提升本地体验；
4. 多 source View package 不依赖单 input rule 推断完整失效关系；
5. 发布的 MoonBit package 已携带 generated source，下游不安装 generator。

参考：[Moon package `rule` and `dev_build`](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html#rule-and-dev_build)。

## Considered Alternatives

- 依赖 dependency package 的 pre-build 自动生成：Moon 的下游构建不会执行依赖包中的任意
  pre-build，发布包也不应要求使用者安装 generator。
- 用单 input/output Moon rule 推导多 source View package 的完整失效关系：Moon rule 模型无法
  表达该依赖图；package-level `generate` 才是规范边界。

## 确定性与原子写入

Generator 必须保证：

- source path normalization 与 stable sorting；
- header 记录 generator、lock format 和所有 input hash；
- single-output file 在目标文件旁写临时文件并原子替换；multi-output package 使用
  同一 target filesystem 的临时目录完整生成后原子替换；
- 失败不修改已存在 output；
- 相同 input 与 lockfile 生成逐 byte 相同的 source artifact；
- 使用当前 Moon toolchain 的 `moonfmt` 产生最终 `.generated.mbt`，随后重定位 source
  map 并计算 ownership hash；
- 不嵌入时间戳和机器绝对路径。

## Diagnostic source mapping

Moon 工具链支持与 generated `.mbt` 同目录的 `.mbt.map.json`，该位置用于 Moon
自动发现。Selene XAML 仓库 tracking `examples/inventory/src/view` 与
`examples/survivors/src/view` 中的 map 作为第一方回归快照；下游应用可按自身 generated
artifact policy tracking 或忽略它。generator 只为仍可能产生 Moon compiler diagnostic
的业务表达式生成 mapping：

- collection 与 property binding member access -> `Path` token；
- item key expression -> `KeyPath`；

静态 layout/property literal、stable node key 与 action route 在 ViewIR/emitter 阶段完成
验证或由 generator 封闭生成，不为这些片段增加逐 fragment mapping。`moonfmt` 产生最终
MoonBit source 后，generator 按表达式顺序重定位保留 mapping 的 generated offset，再生成
source map 与 ownership lock。

generator 检查 XML、Profile 1 schema、namescope 和 static scalar。MoonBit compiler 检查
业务字段、业务类型、package visibility 和最终 target type，diagnostic 仍显示
XAML 行列。

参考：

- [Moon generated diagnostic source-map test](https://github.com/moonbitlang/moon/blob/main/crates/moon/tests/test_cases/build_workflow.rs)
- [Minimal `.mbt.map.json` fixture](https://github.com/moonbitlang/moon/tree/main/crates/moon/tests/test_cases/diag_loc_map_small.in)
