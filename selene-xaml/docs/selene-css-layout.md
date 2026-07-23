# Selene CSS Layout

Selene 布局是受 CSS Flexbox 与 Grid 启发的 XAML vocabulary，底层由 Taffy 引擎执行
measure/arrange。它不是完整的 CSS 实现，但在能力范围内尽量采用 CSS 术语和心智模型。

本文定义 `urn:selene:xaml:ui` 中与布局相关的类型、成员和运行时语义。与这些类型对应的
XAML infoset 映射、markup extension、组件化和状态系统见
[Selene XAML Vocabulary 指南](selene-xaml-vocabulary.md)。

- **Implemented**：generated View 和 Embedded View Host 已贯通，并有自动化回归。
- **Partial**：部分值或部分 target 生效，不能按完整 contract 使用。
- **Planned**：名称和语义已确定，代码尚未实现。
- **Excluded**：当前 vocabulary 有意不公开；Selene 底层存在同名能力也不改变此状态。

## 布局类型概览

| Selene 类型 | CSS / Web 参照 | XAML 近似 | 说明 |
| --- | --- | --- | --- |
| `View` | `<div>` | `Panel` / `Border` | 通用容器，承担 box、布局、焦点和事件角色 |
| `Flex` | CSS Flexbox | `StackPanel` / `WrapPanel` | 弹性布局，支持方向、换行、gap、grow/shrink/basis 和轴向对齐 |
| `Grid` | CSS Grid | `Grid` | 二维布局，使用 `fr` 单位、`minmax()`、`repeat()` 和 attached placement |
| `ScrollView` | overflow container | `ScrollViewer` | 可滚动节点，使用 `Overflow` 控制轴向滚动和 clipping |

## Measure 与 arrange

Selene 布局遵循两阶段模型：父节点在 measure 阶段给出可用空间，子节点返回 desired size；
父节点在 arrange 阶段分配最终 layout slot，子节点再根据尺寸、margin 和 alignment 决定
slot 内的实际矩形。

- `Auto` 使用内容或子树的 desired size，显式尺寸仍受 min/max 约束。
- 文本启用换行时，`Auto` 高度按约束宽度测量换行后的行数。
- 图片的 `Auto` 尺寸使用资源固有尺寸，仅约束一个轴时保持固有宽高比。
- 结果投影为 ECS layout stores，不公开 `MeasureOverride`、`ArrangeOverride` 等虚方法 API。

## 通用 box 属性

`View`、`Flex`、`Grid`、`ScrollView`、`Text`、`Image` 和 `Button` 共享下列 box 成员。
共享成员表示相同的 ECS 投影，不构成类似 WPF `FrameworkElement` 的公开继承层级。

| 成员 | 目标语义 | 参照 | 状态 |
| --- | --- | --- | --- |
| `Width`、`Height` | `Auto` 使用 desired size；无单位数值为逻辑像素；`%` 以 containing block 对应 content size 为基准 | CSS `width`/`height` | Implemented |
| `MinWidth`、`MinHeight`、`MaxWidth`、`MaxHeight` | 在 measure/arrange 中约束最终尺寸；min 在约束冲突时优先于 max | CSS `min-width`/`max-width` 等 | Planned |
| `Margin` | 位于 border 外侧，不属于命中区域；一值表示四边，四值空格分隔，顺序 `top right bottom left` | CSS `margin` | Partial |
| `Padding` | 位于 border 内侧，缩小 content box；同一空格分隔语法 | CSS `padding` | Partial |
| `HorizontalAlignment` | `Stretch`（默认）、`Left`、`Center`、`Right` | CSS `justify-self` / `align-self` 方向组合 | Planned |
| `VerticalAlignment` | `Stretch`（默认）、`Top`、`Center`、`Bottom` | 同上 | Planned |
| `ZIndex` | 同一 parent 下数值较大的节点后绘制；相同值保持 tree order | CSS `z-index` | Implemented |

`HorizontalAlignment`、`VerticalAlignment` 描述节点在父节点分配的 layout slot 中的位置，
与 `Text.Align` 分属布局和排版两个命名空间。显式 `Width` 或 `Height` 覆盖对应轴的
`Stretch` 尺寸，但仍保留该轴的居中定位语义。

## Flex

`Flex` 是 Selene 的主要布局节点。单行堆叠和换行语义对标 CSS Flexbox。

| 成员 | 值与默认值 | 参照 | 状态 |
| --- | --- | --- | --- |
| `Direction` | `Column`（默认）、`Row`、`ColumnReverse`、`RowReverse` | CSS `flex-direction` | Implemented |
| `Wrap` | `NoWrap`（默认）、`Wrap`、`WrapReverse` | CSS `flex-wrap` | Planned |
| `Gap`、`RowGap`、`ColumnGap` | 非负逻辑像素；轴专用值覆盖 `Gap` | CSS `gap` / `row-gap` / `column-gap` | Implemented |
| `Grow`、`Shrink`、`Basis` | `0`、`1`、`Auto`；决定剩余空间分配和收缩 | CSS `flex-grow` / `flex-shrink` / `flex-basis` | Implemented |
| `JustifyContent` | `Start`（默认）、`End`、`Center`、`SpaceBetween`、`SpaceAround`、`SpaceEvenly` | CSS `justify-content` | Planned |
| `AlignItems` | `Stretch`（默认）、`Start`、`End`、`Center`、`Baseline` | CSS `align-items` | Planned |
| `AlignContent` | `Stretch`（默认）、同上值及三种 `Space*` 值 | CSS `align-content` | Planned |
| `AlignSelf` | `Auto`（默认）或 `AlignItems` 值；设置在 flex child 上 | CSS `align-self` | Planned |

```xml
<Flex Width="100%" Grow="1" Direction="Row" Gap="14">
  <ScrollView Width="100%" Grow="1" Overflow="Scroll" />
</Flex>
```

## Grid

`Grid` 使用 CSS Grid 术语：`fr` 单位、`minmax()`、`repeat()`、命名的 grid line placement
和 `AutoFlow`。行列定义以紧凑字符串形式写在属性上，省去构造中间对象树。

| 成员 | 目标语义 | 状态 |
| --- | --- | --- |
| `Rows` | 空格分隔的 track 列表：`Auto`、像素、`%`、`fr`、`minmax(min,max)`、`repeat(count,track...)` | Implemented |
| `Columns` | 同 `Rows` | Implemented |
| `RowGap`、`ColumnGap` | 行列之间的非负逻辑像素间距 | Implemented |
| `AutoFlow` | `Row`（默认）、`Column`、`RowDense`、`ColumnDense` | Implemented |
| `Grid.Row`、`Grid.Column` | 零基 line index，默认 `0` | Planned |
| `Grid.RowSpan`、`Grid.ColumnSpan` | 正整数 span，默认 `1` | Planned |

省略 `Rows` 和 `Columns` 时，Grid 创建一个填满可用空间的单行单列。`Auto` track 按该行
或列中最大的 child desired size 测量；像素和百分比 track 使用固定尺寸；`fr` track 按权重
分配扣除固定、Auto 和 gap 后的剩余空间。多个 child 位于同一 cell 时允许重叠，绘制顺序
由 `ZIndex` 和 tree order 决定。

```xml
<Grid Rows="Auto 1fr" Columns="240 1fr"
      RowGap="12" ColumnGap="16">
  <Text Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2"
        Text="Loadout" />
  <Flex Grid.Row="1" Grid.Column="0" Direction="Column" Gap="8" />
  <ScrollView Grid.Row="1" Grid.Column="1" />
</Grid>
```

### Grid track 语法

`Rows` 和 `Columns` 接受空格分隔的 track 列表，每个 track 可以是：

| 语法 | 含义 | 示例 |
| --- | --- | --- |
| `Auto` | 按内容 desired size | `Auto` |
| 数字 | 逻辑像素 | `240` |
| `N%` | 百分比 | `50%` |
| `Nfr` | 按权重分配剩余空间 | `1fr`、`2.5fr` |
| `minmax(min, max)` | 约束范围，min/max 各为上述 track | `minmax(100, 1fr)` |
| `repeat(N, track...)` | 重复 N 次；`N` 可为 `auto-fill` 或 `auto-fit` | `repeat(3, 1fr)`、`repeat(auto-fill, 200)` |

## 定位

| 成员 | 值 | 参照 | 状态 |
| --- | --- | --- | --- |
| `Position` | `Relative`（默认）、`Absolute` | CSS `position` | Partial |
| `Left`、`Top`、`Right`、`Bottom` | `Auto`（默认）、像素、`%`；仅 `Absolute` 节点生效 | CSS `left`/`top`/`right`/`bottom` | Partial：`Left`/`Top` 像素已实现 |

绝对节点退出普通 flow，inset 相对 containing block 的 padding box 解析，不影响 sibling
desired size。左右同时指定且 `Width="Auto"` 时由两侧 inset 决定宽度；上下同理。
`AspectRatio` 暂为 Excluded；图片固有宽高比由 measure 规则处理。

## ScrollView 与 overflow

`View`、`Flex`、`Grid` 和 `ScrollView` 共享统一的 overflow 模型：

| 成员 | 值 | 参照 | 状态 |
| --- | --- | --- | --- |
| `Overflow` | `Visible`（默认）、`Hidden`、`Scroll`、`Clip` | CSS `overflow` | Partial：`ScrollView` 默认 `Scroll` |
| `ScrollbarWidth` | 非负逻辑像素 | CSS `scrollbar-width` | Partial |

`Visible` 不裁剪；`Hidden` 裁剪并禁止滚动；`Scroll` 裁剪并允许滚动；`Clip` 裁剪但不
创建 scroll container。`ScrollView` 默认 `Overflow="Scroll"`，其他容器默认 `Visible`。

## 文本与图片的固有尺寸

`Text` 和 `Image` 参与布局时提供 intrinsic measure：

- **`Text`**：`Text` 属性为纯文本，排版属性包括 `FontFamily`、`FontSize`、`Color`、
  `Align`、`Wrap`、`Overflow`。启用 `Wrap="WordWrap"` 时按约束宽度测量换行后行数。
  `Span` 子元素可定义富文本片段，runtime 汇总为父 `Text` 的 span 列表。

- **`Image`**：`Source` 加载图像，固有尺寸来自资源。`Fit` 取值 `Stretch`、`Contain`、
  `Cover`、`None`（对标 CSS `object-fit`）。`Tint` 叠加颜色，`SourceRegion` 裁剪源图。

## 响应式布局

显著 viewport 变化使用 visual state 思路：应用把明确的 viewport class 或宽度输入
ViewModel，由 `VisualStateGroup` 或 `If` 选择对应布局。当前 generated View 只贯通 `If`。
layout query、size-changed event 和 adaptive trigger 在 Embedded View Host 提供完整 transaction
语义后才进入 vocabulary。

## 布局实现覆盖

| 能力 | Parser / infoset | Generated View / Host | 目标状态 |
| --- | --- | --- | --- |
| Flex direction、gap、grow/shrink/basis | Accepted | `CG-LAYOUT-01`、`INVENTORY-LAYOUT-01` | Implemented |
| `Auto`、像素、百分比 width/height | Accepted | `CG-LAYOUT-01`、`INVENTORY-LAYOUT-01` | Implemented |
| Grid track 定义、placement、span | `Grid.Row/Column` 可保留 | `Grid` element 生成时明确报 unsupported | Planned |
| min/max constraints | Accepted | 生成时明确报 unsupported | Planned |
| Flex wrap 和轴向对齐 | Accepted | 未投影到 Selene layout stores | Planned |
| 四边 absolute inset | Accepted | 仅像素 `Left`/`Top` | Partial |
| overflow 裁剪与滚动 | Accepted | 仅 Visible/Scroll 映射 | Partial |
| 文本换行后的 Auto measure、图片 intrinsic measure | Accepted | 尚无 acceptance regression | Planned |
| layout query / adaptive trigger | — | Host contract 未暴露 | Planned |

## 参考资料

- [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Flexible_box_layout/Basic_concepts)
- [CSS Grid](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout/Basic_concepts_of_grid_layout)
- [CSS Box Model](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_box_model)
- [CSS Overflow](https://developer.mozilla.org/en-US/docs/Web/CSS/overflow)
- [Taffy Layout Engine](https://docs.rs/taffy)
