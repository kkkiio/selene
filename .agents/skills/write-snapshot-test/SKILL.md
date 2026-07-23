---
name: write-snapshot-test
description: 为 Selene 编写或修改语义状态与生成 artifact 快照测试。用于测试 parser infoset、诊断、公开 API、ECS 层级、Selene UI stores、绑定、结构调和、事件、视觉状态、热重载，以及 generated `.mbt`、source map 和 ownership lock；优先使用黑盒 `*_test.mbt`，对完整生成 package 使用 `@test.Test` file snapshot。
---

# Write Snapshot Test

## 决策：file snapshot vs `inspect` vs `debug_inspect` vs `assert_eq`

| 场景 | 用 | 原因 |
| --- | --- | --- |
| formatter 后的完整 generated file 或 package | `@test.Test::write` / `writeln` + `snapshot` | 保留源码、source map 和 lock 的完整 review diff。 |
| 完整领域对象（typed plan、store 投影、ECS 层级、诊断列表） | `debug_inspect(value)` | snapshot 即文档。`--update` 自动维护，review diff 即可。 |
| 实现 `Show` 的标量 | `inspect(value)` | 比 `debug_inspect` 更可读。 |
| 单个可独立推导的不变量（布尔、计数、关键子串出现/不出现） | `assert_eq(a, b)` | 失败立即定位，不用数 snapshot 里第几个 `true`。 |
| **不可** | 把 `contains` / `length` / `starts_with` 结果包进 `debug_inspect` 的 tuple | 既丢领域值可读性，又丢 `assert_eq` 的定位能力。 |

**核心原则：让工具生成 baseline，不要手写预期值。** `moon test --update` 产出的
snapshot 比 agent 或人手工构造的预期数组/字符串更可靠，且后续实现变化时不用
手工同步。

## 生成文件使用 file snapshot

- 快照 formatter 之后、用户最终获得的 artifact；不要把 emitter 的临时格式当成交付 baseline。
- 单个 artifact 使用与真实文件匹配的 snapshot 后缀，例如 `.mbt` 或 `.json`。
- 多文件 package 在同一个 test 中按稳定顺序写成 `.txt` transcript；用
  `===== <真实文件名> =====` 保留文件边界，并写入每个文件的完整内容。
- `@test.Test::snapshot` 总会抛出测试框架异常。一个 test block 的正常控制流只能在末尾
  生成一个 file snapshot；需要独立 artifact baseline 时拆成多个 test。
- 把所有关系断言放在 `snapshot` 之前。不要捕获 snapshot 异常来继续生成第二份 baseline。
- 排除绝对路径、时间戳、随机 ID、Map 非确定迭代顺序和其他机器相关内容。
- file snapshot 已覆盖的完整源码或 JSON 不再重复使用内联 `inspect` / `debug_inspect`。

```moonbit
async test "snapshots formatted Embedded package" (t : @test.Test) {
  let generated = @generator_io.format_generated_package(
    @codegen.generate_embedded_view_package(source_path, xaml, contract_path, mbti),
  )
  for file in generated.files {
    let header =
      $|===== \{file.path} =====
    t.writeln(header)
    t.write(file.content)
    if !file.content.has_suffix("\n") {
      t.writeln("")
    }
    t.writeln("")
  }
  t.snapshot(filename="canonical_embedded_package.txt")
}
```

## 生成 artifact 的结构化断言

file snapshot 记录完整输出；普通断言验证 snapshot 无法自动证明的跨文件关系：

- ownership lock 中的 SHA-256 等于格式化后 source/source-map 的真实 hash；
- source map 的 `generated_offset` 和 `length` 指向格式化源码中的目标表达式；
- lock output path 与生成 package 文件一一对应且没有重复项。

对 JSON 使用测试私有的 `FromJson` 投影类型，再比较强类型字段。不要为测试公开 production
的私有 lock/source-map record，也不要用字符串 `contains` 检查 JSON 字段或 hash。
`match` / `is` 适合区分领域 enum；JSON contract 优先解码成 typed struct。

```moonbit
struct SnapshotLockedOutput {
  owner : String
  path : String
  sha256 : String
} derive(FromJson)

struct SnapshotOwnershipLock {
  outputs : Array[SnapshotLockedOutput]
} derive(FromJson)

let lock : SnapshotOwnershipLock = @json.from_json(@json.parse(formatted_lock))
let hashes : Map[String, String] = Map([])
for output in lock.outputs {
  assert_eq(output.owner, "selene")
  hashes[output.path] = output.sha256
}
assert_eq(hashes.get("view.generated.mbt"), Some(formatted_source_hash))
```

## 反模式

### 布尔谓词包进 snapshot tuple（坏）

```moonbit
debug_inspect(
  (guest.contains("pub fn DemoUi::demo_ui"), guest.contains("@tree.apply"), ...),
  content=((true, true, ...)),
)
// review 看不到实际输出，失败时不知道第几个 true 变了。
```

### 手写预期数组做相等断言（坏）

```moonbit
assert_eq(
  generated.files.map(file => file.path),
  ["moon.pkg", "state.generated.mbt", "view.generated.mbt", ...],
)
// 文件列表调整后必须手工同步预期值。
```

### 拼凑"预期 tuple"再对比（坏）

```moonbit
assert_eq((a, b.field1, b.field2), (expected_a, expected_b1, expected_b2))
// 应该 debug_inspect((a, b))，让 --update 生成完整 baseline。
```

### 正确做法

```moonbit
// 领域值 — 直接使用内联 snapshot
debug_inspect(generated.files.map(file => file.path))
debug_inspect(plan)

// 独立不变量 — 单行断言，失败定位精确
assert_eq(generated.files.length(), 3)
assert_eq(guest.contains("@entity"), false)
```

## 观察边界

按以下优先级选择快照对象：

1. 公开返回值、`XamlError` 诊断码和 source span。
2. `XamlDocument` 中与规格直接对应的 object/member/value 结构。
3. `entity_by_name` 获取的 Entity、公开 Entity 父子层级和 Selene UI stores。
4. `XamlActionContext`、asset events、focus、scroll 和 interaction 等可观察状态。
5. keyed list 中的 Entity 复用、局部结构替换和热重载前后的语义投影。

- 快照完整领域值或简短的语义投影；不为凑成大快照合并无关断言。
- 排除 Entity 数字 ID、Map 迭代顺序、runtime 私有 record 和其他偶然实现细节。
- 不为了让 `inspect` 编译而拆散公开结构、丢弃 `Option` 或增加 `unwrap`。

## 黑盒约束

- 默认写 `*_test.mbt`，通过 `@infoset`、`@parser`、`@viewir` 等公开 API 调用。
- 不为测试增加 `_for_test` 公开符号，也不为了通过快照扩大 facade。
- 私有状态不可观察时，先改写为公开行为断言。只有真实业务调用方需要该查询时，才设计新 API。
- 不读取私有 record、opaque handle 内部字段或 package-private 实现。

## 更新 baseline

- 先运行定向测试，仅在行为变化符合当前规格时使用 `moon test ... --update`。
- 逐项审查生成的 `content` 或 `__snapshot__` diff，不盲目接受大量 baseline 更新。
- 将 `--update` 生成的 baseline 作为待审查产物；不手工美化或重写。结果不正确时修改被观察表达式，再重新运行 `--update`。
- 对 package transcript 逐段审查生成源码、source map、lock hash 和文件边界；确认没有绝对路径、时间戳或临时目录。
- 按项目指南运行 parser/codegen 的 JS 和 native 检查。
- 定向单文件时使用 `moon test <test-file> --target js`；当前 Moon CLI 没有 `--filter` 参数，不臆造测试过滤选项。

```bash
moon test src/parser --target js
just fmt
just check
```
