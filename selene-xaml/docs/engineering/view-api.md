# Generated View API

状态：**Accepted**

Generated API 由 Embedded View package 提供，以 Selene Entity 作为 mounted View 身份。

```moonbit
InventoryView::mount(entity, model)
InventoryView::replace(entity, model)
InventoryView::apply(entity, patches)
InventoryView::unmount(entity)
```

Generated package 在当前 World 中以 Entity 保存私有 View record，并静态调用
`@ui_view.ViewHost`。

Generated package 同时公开 typed Action EventBus。调用方读取 Action、更新 authoritative Model，
再通过 `replace` 或 `apply` 驱动 View。
