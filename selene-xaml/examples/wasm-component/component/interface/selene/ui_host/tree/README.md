XAML-independent, batched mutation capability implemented by Selene.

The guest owns business state and reconciliation. The host owns the real
Selene entities and validates each mutation batch before committing it.