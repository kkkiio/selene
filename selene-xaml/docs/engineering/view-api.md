# Generated View API

状态：**Accepted**

Generated API 分为 Embedded View package 和 Component Guest package。两种交付方式都以 Selene
Entity 作为 mounted View 身份；区别是 Embedded package 直接接收 `@entity.Entity`，Component
Guest 通过业务 WIT 接收该 Entity 的 `u32` ID。

## Embedded View

```moonbit
InventoryView::mount(entity, model)
InventoryView::replace(entity, model)
InventoryView::apply(entity, patches)
InventoryView::unmount(entity)
```

Generated package 在当前 World 中以 Entity 保存私有 View record，并静态调用 Selene UI Host。

## Component Guest

业务项目拥有 WIT interface；Selene XAML 根据这份 interface 和 XAML 生成 Guest 实现：

```wit
interface inventory-ui-api {
  mount: func(entity: u32, model: inventory-model);
  replace: func(entity: u32, model: inventory-model);
  apply: func(entity: u32, patches: list<inventory-patch>);
  handle-event: func(entity: u32, event: ui-event) -> option<inventory-action>;
  update: func();
  unmount: func(entity: u32);
}
```

一个 Component instance 固定绑定一个 Selene World。Guest memory 中使用
`Map[UInt, GeneratedGuestRecord]` 保存 View state，因此不同 World 即使出现相同 UInt ID，也不会
进入同一个 Guest Map。

Host 负责检查真实 Entity 的 `is_alive()`。Entity 死亡时，Host 先调用 Guest `unmount(entity)`
删除 View state，再清理 Selene UI tree；每帧清理完成后调用 Guest `update()`。Guest 无法从 UInt
构造或查询 Selene Entity。

`handle-event` 是 Host/Guest ABI。业务项目可以把返回的 typed Action 接入自己的 EventBus；Selene
XAML 不生成依赖业务类型的 Host adapter。

具体内存与 lifecycle 见 [WebAssembly Component Guest Package](wasm-component-guest-package.md) 和
[WebAssembly Component Host](wasm-component-host.md)。
