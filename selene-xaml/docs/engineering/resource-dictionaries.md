# Resource dictionaries

Selene XAML resource dictionaries are compile-time, lexically scoped collections
of typed scalar constants. They centralize design tokens without adding a
runtime service locator or a second property-precedence system to Selene UI.

## Authoring model

A visual object may declare one `Resources` property containing a
`ResourceDictionary`. Dictionaries accept keyed `Color`, `x:String`,
`x:Double`, and `x:Int32` scalar objects:

```xml
<View.Resources>
  <ResourceDictionary Source="../theme.xaml">
    <x:Double x:Key="Radius.LocalPanel">12</x:Double>
  </ResourceDictionary>
</View.Resources>
```

`ResourceDictionary.Source` is resolved relative to the document that declares
it. A source document has `ResourceDictionary` as its root. Sources may import
other sources, and `MergedDictionaries` may combine inline dictionaries.
Source cycles, missing source inputs, duplicate local keys, unkeyed entries,
and non-scalar entries fail compilation with the originating XAML span.

Local entries override imported and merged entries. A nested visual resource
scope shadows its ancestors. Within one dictionary, `StaticResource` aliases
may refer to imported resources or earlier local entries; forward references
are rejected as missing keys.

## Compilation

`{StaticResource Key}` is resolved before ViewIR value sealing. The selected
scalar text is converted by the consuming member's existing typed literal
lowering, so one resource cannot bypass Color, Double, Rect, layout-value,
Grid-track, or enum validation. Generated View packages contain ordinary
`IRConstant` values and require no resource lookup at runtime.

The compiler library receives external documents as explicit
`ResourceDocument` inputs. It never reads the filesystem. The native CLI
discovers `Source` references recursively, reads them, and records every
normalized path and SHA-256 in the ownership lock and generated source header.

## Deliberate boundary

This profile serves shared design tokens. It does not construct arbitrary
objects, styles, brushes, templates, or `DynamicResource` values.
Runtime-selected themes should enter a generated View through typed model
fields and bindings, preserving explicit update boundaries and target types.
