# Selene XAML Profile 1 conformance matrix

Baseline: [MS-XAML-2017 XAML Object Mapping Specification](https://learn.microsoft.com/en-us/openspecs/microsoft_domain_specific_languages/ms-xaml-2017/6e54cd2e-4421-4c06-ae3a-15d2762c8899).

Selene XAML Profile 1 is a selected implementation of the object-mapping
model. It does not claim complete MS-XAML-2017 conformance. Status values are
`Conformant`, `Partial`, `Not Implemented`, and `Not Applicable`. A test ID
names the automated test or fixture that exercises the behavior; `-` marks an
intentional exclusion.

Profile parsing produces an Infoset, then the compiler combines it with an
`.mbti` business contract and seals a typed `ViewIR`. The Embedded emitter
generates Entity-based APIs and static calls to `selene/ui_view`.
Successful batches commit incrementally; automated coverage is
`VH-INCREMENTAL-01`. Visual states seal typed namescope targets and bindings
into ViewIR, then the Host applies ordered state overlays and transitions to
retained Entities; coverage is `VI-IR-04` and `VH-VISUAL-STATE-01`.

## Section 4 - Information Set Type System

| Spec | Requirement summary | Status | Selene behavior | Deviation rationale | Test ID |
| --- | --- | --- | --- | --- | --- |
| 4 | Provide the primitive types used by schema and instance infosets. | Partial | Public qualified-name, span, schema, member, object, text, set/map and ordered-array representations are provided. | Profile API exposes only types needed by the selected mapping. | PC-SCHEMA-01 |
| 4.1 | Text String is a finite Unicode character sequence. | Conformant | MoonBit `String` represents source and text values. | None within strict UTF-8 input. | PC-INFOSET-01 |
| 4.2 | XamlName follows the specified name grammar. | Partial | XML names are validated by `xml-mbt`; qualified names retain prefix, local name and URI. | The API does not expose an independent XamlName validator. | PC-DUP-01 |
| 4.3 | Namespace URI is an absolute-or-empty URI string. | Partial | Namespace URIs are preserved and used as schema identity. | General URI normalization is not performed. | PC-INFOSET-01 |
| 4.4 | Boolean has true and false values. | Conformant | `XamlScalarType::Bool` models schema values; generated literals and typed binding expressions use MoonBit `Bool`. | Intrinsic x:Boolean object elements are excluded. | INVENTORY-01, SURVIVORS-01 |
| 4.5 | Allowed Location identifies attribute/member/content placement. | Partial | Schema members declare attached/collection/required placement properties. | The full abstract Allowed Location algebra is not public. | PC-SCHEMA-02 |
| 4.6 | XML Namespace Mapping relates prefixes and namespace URIs. | Conformant | Every element carries authored namespace declarations and resolved names. | None. | PC-INFOSET-01 |
| 4.7 | Set is unordered and duplicate-free. | Conformant | `Map` is used for schemas, member identity, namescopes and registries. | None. | PC-SCHEMA-03 |
| 4.8 | Ordered Collection preserves order and permits duplicates where legal. | Conformant | `Array` preserves member values, children, setters, groups and transitions. | Legality is checked at the relevant mapping rule. | PC-INFOSET-01 |

## Section 5 - Xaml Schema Information Set

| Spec | Requirement summary | Status | Selene behavior | Deviation rationale | Test ID |
| --- | --- | --- | --- | --- | --- |
| 5 | Model schemas using schema, type, member, syntax and constructor items. | Partial | `XamlSchema`, `XamlTypeDefinition`, `XamlMemberDefinition` and scalar syntax categories are public. | Value/pattern syntax and constructor items are excluded. | PC-SCHEMA-01 |
| 5.1 | Schema item identifies its types and directives. | Partial | A schema owns a namespace URI and unique type map; intrinsic directives are recognized by the parser. | Directives are not stored as a second public schema collection. | PC-SCHEMA-01 |
| 5.1.1 | Enforce schema-item constraints. | Partial | Registry/build validation enforces the constraints represented by Profile 1. | Constraints over excluded properties are not modeled. | PC-SCHEMA-03 |
| 5.1.1.1 | Schema properties have the specified types. | Partial | Public fields use concrete MoonBit types. | Excluded schema properties are absent. | PC-SCHEMA-01 |
| 5.1.1.2 | Items in directives are directives. | Not Applicable | Profile directives are intrinsic parser rules. | No configurable directives collection exists. | - |
| 5.1.1.3 | Type names in a schema are unique. | Conformant | `XamlSchemaBuilder::add_type` rejects duplicate type names. | None. | PC-SCHEMA-03 |
| 5.1.1.4 | Directive names in a schema are unique. | Not Applicable | Intrinsic directive names are fixed. | No configurable directives collection exists. | - |
| 5.1.2 | Non-normative schema notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 5.2 | XamlType item describes object type metadata. | Partial | Name, content member, member map, collection marker and markup-extension marker are modeled. | Assignability, construction, dictionary and retrieval metadata are excluded. | PC-SCHEMA-02 |
| 5.2.1 | Enforce XamlType constraints. | Partial | Content/member and extension constraints represented by the API are enforced. | Excluded metadata cannot be constrained. | PC-SCHEMA-03 |
| 5.2.1.1 | XamlType properties have the specified types. | Partial | Represented fields are statically typed. | The full property set is absent. | PC-SCHEMA-01 |
| 5.2.1.2 | Content member is available to the type. | Conformant | Parser resolves a type's named content member from its member map. | None. | PC-INFOSET-01 |
| 5.2.1.3 | Name member is available to the type. | Partial | Selene uses `Id` plus intrinsic `x:Name`; both feed the compiler namescope. | A general schema-defined name-member property is not modeled. | PC-DUP-01 |
| 5.2.1.4 | Content member is mutually exclusive with list/dictionary form. | Partial | Built-in types use content members; collection-valued members are explicit. | General list/dictionary XamlTypes are excluded. | PC-INFOSET-01 |
| 5.2.1.5 | List and dictionary forms are mutually exclusive. | Not Applicable | General list and dictionary type metadata is absent. | Profile collections are member values. | - |
| 5.2.1.6 | Allowed types occur only on lists/dictionaries. | Not Applicable | Allowed-types metadata is absent. | Profile validates concrete UI schemas. | - |
| 5.2.1.7 | Allowed key types occur only on lists/dictionaries. | Not Applicable | Allowed-key-types metadata is absent. | ViewIR lowering resolves `ItemsControl.KeyPath` to a stable typed item field. | VI-IR-01 |
| 5.2.1.8 | Markup extensions declare a return type. | Not Implemented | Built-in extensions have fixed compiler semantics. | Return-value type metadata is outside Profile 1. | - |
| 5.2.1.9 | Return type appears only on markup extensions. | Not Applicable | Return-value type metadata is absent. | Same exclusion as 5.2.1.8. | - |
| 5.2.1.10 | Only markup extensions have constructors. | Not Implemented | Arbitrary constructor metadata is absent. | Profile parses extension arguments without general constructors. | PC-ME-01 |
| 5.2.1.11 | Constructor arities are unique. | Not Applicable | Constructor metadata is absent. | Arbitrary constructors are excluded. | - |
| 5.2.2 | Non-normative XamlType notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 5.3 | XamlMember item describes properties, events, directives and attachable members. | Partial | Value type, attached, collection and required flags are public. | Static/event/read-only and full attachable metadata are excluded. | PC-SCHEMA-02 |
| 5.3.1 | Enforce XamlMember constraints. | Partial | Unique member names and legal attached usage are enforced. | Constraints over excluded fields are not modeled. | PC-INFOSET-01 |
| 5.3.1.1 | XamlMember properties have specified types. | Partial | Represented fields are statically typed. | Full property set is absent. | PC-SCHEMA-01 |
| 5.3.1.2 | Member names are unique for an owner. | Conformant | Member maps and parsed object members reject duplicates. | None. | PC-DUP-01 |
| 5.3.1.3 | Member kind is internally consistent. | Partial | Attached and collection kinds are explicit and validated. | Static/event/directive kinds are not user-definable. | PC-INFOSET-01 |
| 5.3.1.4 | Member has owner type or is a directive. | Conformant | Normal/attached members resolve through an owner schema; intrinsic `x:` names are directives. | None for supported directives. | PC-INFOSET-01 |
| 5.3.1.5 | Owner type owns its member. | Conformant | Unknown normal members are rejected. | None. | PC-INFOSET-01 |
| 5.3.1.6 | Only list/dictionary/static members may be read-only. | Not Applicable | Read-only members are not modeled. | Generated code submits only declared typed tree mutations. | - |
| 5.3.1.7 | Attachable members contain required attachable metadata. | Partial | `is_attached` is required and checked against owner schema. | Getter/setter method metadata is absent. | PC-INFOSET-01 |
| 5.3.1.8 | Attachable-only properties do not appear elsewhere. | Partial | The compact schema has one attached flag. | Full attachable property set is absent. | PC-INFOSET-01 |
| 5.3.1.9 | Event members have x:XamlEvent type. | Not Applicable | Supported Click/Focus action attributes lower to stable-ID routes and a view-specific typed action enum whose public variants participate in the generated ABI fingerprint. | The XamlEvent member model is excluded. | VI-IR-01, CG-ABI-01 |
| 5.3.1.10 | Directives omit unsupported member properties. | Not Applicable | Directives are intrinsic parser rules. | They are not `XamlMemberDefinition` instances. | - |
| 5.3.1.11 | Target-type metadata is legal only for assignable owners. | Not Applicable | Target-type/assignability metadata is absent. | Attached members resolve by explicit owner type. | - |
| 5.3.1.12 | Markup-extension bracket character arrays have required length. | Not Implemented | Profile uses the standard `{` and `}` pair only. | Custom bracket characters are excluded. | - |
| 5.3.1.13 | Bracket characters are not XamlName characters. | Conformant | Fixed braces are not XamlName characters. | Customization is absent. | PC-ME-01 |
| 5.3.1.14 | Disallowed markup-extension bracket characters are rejected. | Conformant | Only fixed braces are recognized; unbalanced/invalid forms fail. | Custom bracket sets are excluded. | PC-ME-02 |
| 5.3.2 | Non-normative XamlMember notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 5.4 | Text Syntax item describes lexical conversion. | Partial | The compiler converts String, Bool, Int, Double, box-shaped values, and `Auto`/pixel/percent layout values represented by the shared tree contract. | The abstract syntax object is simplified to `XamlScalarType`; unsupported value shapes do not enter generated source. | CG-VIEW-01, CG-LAYOUT-01, INVENTORY-01, SURVIVORS-01 |
| 5.4.1 | Enforce Text Syntax constraints. | Partial | Compiler failures retain XAML spans; generated binding and KeyPath expressions carry Moon diagnostic mappings whose offsets are relocated after `moonfmt`. | Pattern/value syntax composition is excluded. | CG-VIEW-01, CG-FORMAT-02 |
| 5.4.1.1 | Text Syntax properties have specified types. | Partial | The compact enum is statically typed. | Full infoset properties are absent. | PC-SCHEMA-01 |
| 5.4.2 | Non-normative Text Syntax notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 5.5 | Value Syntax item represents literal syntax. | Not Implemented | Literal conversion is implemented directly by scalar converters. | No public Value Syntax item exists. | - |
| 5.5.1 | Enforce Value Syntax constraints. | Not Applicable | Value Syntax item is absent. | See 5.5. | - |
| 5.5.1.1 | Value Syntax properties have specified types. | Not Applicable | Value Syntax item is absent. | See 5.5. | - |
| 5.6 | Pattern Syntax item represents composed grammar. | Not Implemented | Markup-extension grammar is implemented by a dedicated parser. | No public Pattern Syntax item exists. | PC-ME-01 |
| 5.6.1 | Enforce Pattern Syntax constraints. | Not Applicable | Pattern Syntax item is absent. | See 5.6. | - |
| 5.6.1.1 | Pattern Syntax properties have specified types. | Not Applicable | Pattern Syntax item is absent. | See 5.6. | - |
| 5.7 | Constructor item describes positional construction. | Not Implemented | Arbitrary constructors and factories are excluded. | Components use generated typed named props. | - |
| 5.7.1 | Enforce constructor constraints. | Not Applicable | Constructor items are absent. | See 5.7. | - |
| 5.7.1.1 | Constructor properties have specified types. | Not Applicable | Constructor items are absent. | See 5.7. | - |

## Section 6 - Xaml Information Set

| Spec | Requirement summary | Status | Selene behavior | Deviation rationale | Test ID |
| --- | --- | --- | --- | --- | --- |
| 6 | Represent document, object, member and text nodes. | Conformant | Public `XamlDocument`, `XamlObjectNode`, `XamlMemberNode`, `XamlTextNode` and value union preserve source spans. | Markup extensions are additionally retained as typed values. | PC-INFOSET-01 |
| 6.1 | Document item owns the root and schema context. | Partial | Document owns source URI, root, root namespace nodes and diagnostics. | It references a registry during parsing instead of retaining an authoritative schema item. | PC-INFOSET-01 |
| 6.1.1 | Enforce document constraints. | Conformant | Exactly one rooted object tree is required. | None for represented properties. | PC-DOC-01 |
| 6.1.1.1 | Document properties have specified types. | Conformant | Public fields are concrete MoonBit types. | None. | PC-INFOSET-01 |
| 6.1.1.2 | Xaml infoset has tree structure. | Conformant | Parser builds a single owned tree and rejects multiple roots/trailing content. | Compiler namescope/reference resolution does not change infoset ownership. | PC-DOC-01 |
| 6.2 | Object node identifies type, members and parent relation. | Partial | Object type, ordered members, namespace nodes and source span are retained. | Parent is structural rather than a public back-reference. | PC-INFOSET-01 |
| 6.2.1 | Enforce object-node constraints. | Partial | Type/member identity, duplicate rules and root-only `x:Class` are enforced. | General event and CLR class rules are excluded. | PC-DUP-01, PC-DIRECTIVE-02 |
| 6.2.1.1 | Object-node properties have specified types. | Conformant | Represented fields are statically typed. | None. | PC-INFOSET-01 |
| 6.2.1.2 | Event values require x:Class on root. | Not Applicable | XamlEvent is excluded; Selene action attributes generate typed View actions and `x:Class` names the generated View identity. | No CLR event-owner class is generated. | VI-IR-01, CG-VIEW-01 |
| 6.2.1.3 | Object cannot contain duplicate member nodes. | Conformant | Attribute/property-element collisions and repeated singular members fail. | Collection content is accumulated into one member node. | PC-DUP-01 |
| 6.2.1.4 | Parent member contains the object node. | Conformant | Recursive descent inserts each object into exactly one member value array. | No public parent pointer is stored. | PC-INFOSET-01 |
| 6.2.2 | Enforce object validity constraints. | Partial | Applicable name, member, text and intrinsic-extension rules are checked. | Construction, XData, static and array constraints are excluded. | PC-DUP-01 |
| 6.2.2.1 | Do not set both x:Name and schema name member. | Conformant | `Id` and `x:Name` are the same Selene namescope and cannot coexist on one node. | `Id` is Selene's schema name member. | PC-DUP-01 |
| 6.2.2.2 | Do not set both xml:lang and language member. | Not Implemented | `xml:lang` and language members are excluded. | Game UI localization remains application data. | - |
| 6.2.2.3 | Non-default-constructible types require constructor parameters. | Not Applicable | Profile types lower to typed tree and generated control flow. | Arbitrary constructors are excluded. | - |
| 6.2.2.4 | Constructor parameters match constructor metadata. | Not Applicable | Constructor metadata is absent. | Components use generated typed named props. | - |
| 6.2.2.5 | Initialization text matches text syntax. | Partial | `x:Initialization` is represented and literal text conversion exists. | General object initialization is not evaluated. | PC-DIRECTIVE-01 |
| 6.2.2.6 | Initialization text cannot coexist with other member values. | Partial | Duplicate directive/member structure is rejected. | Full construction semantics are not evaluated. | PC-DIRECTIVE-01 |
| 6.2.2.7 | x:XData appears only in XData members. | Not Implemented | XData is rejected as unknown/unsupported. | XML data embedding is excluded. | - |
| 6.2.2.8 | x:TypeExtension references a valid type. | Partial | `{x:Type ...}` is parsed and evaluated to a schema type name string. | The symbolic type is consumed at build time. | PC-ME-03 |
| 6.2.2.9 | x:StaticExtension references a valid member. | Not Implemented | `x:Static` is absent from the intrinsic schema. | Static member access is excluded. | - |
| 6.2.2.10 | Array contents have assignable types. | Not Implemented | Intrinsic x:Array is excluded. | Repeated UI data enters generated APIs as typed business arrays. | - |
| 6.2.2.11 | Assignable-type substitution is restricted to retrieved objects. | Not Applicable | Assignability/retrieved-object metadata is absent. | Custom components use exact QNames resolved by the generation unit or sidecar. | - |
| 6.2.3 | Non-normative object-node note. | Not Applicable | Informational section. | No normative requirement. | - |
| 6.3 | Member node owns one or more object/text values. | Conformant | Member QName, ordered values, attached/directive flags and span are retained. | None within represented fields. | PC-INFOSET-01 |
| 6.3.1 | Enforce member-node constraints. | Partial | Cardinality, owner/member identity and supported directives are checked. | Dictionary, XData and unsupported class modifiers are excluded. | PC-INFOSET-01 |
| 6.3.1.1 | Member-node properties have specified types. | Conformant | Public fields are concrete MoonBit types. | None. | PC-INFOSET-01 |
| 6.3.1.2 | Multiple values occur only in collection/directive contexts. | Conformant | Non-collection property elements reject more than one value; content collections accumulate. | Selene explicitly marks collection members. | PC-DUP-01 |
| 6.3.1.3 | x:Items appears only for list/dictionary content. | Partial | `x:Items` is recognized and represented. | General list/dictionary construction is not evaluated. | PC-DIRECTIVE-01 |
| 6.3.1.4 | Dictionary content follows key/value rules. | Not Implemented | Resource dictionaries and x:Key are excluded. | Generated keyed `ItemsControl` reconciliation uses a ViewIR-resolved `KeyPath`. | VI-IR-01, INVENTORY-01, SURVIVORS-01 |
| 6.3.1.5 | XML data members follow XData rules. | Not Implemented | XData is excluded. | Profile is UI object mapping only. | - |
| 6.3.1.6 | x:Class obeys root/class rules. | Partial | A literal `x:Class` is retained on the document root for generated View identity; nested use is rejected. | CLR namespace and runtime construction semantics are outside the MoonBit generator profile. | PC-DIRECTIVE-02, VI-IR-01 |
| 6.3.1.7 | x:Subclass obeys class rules. | Not Implemented | x:Subclass is rejected. | Generated View types do not model CLR inheritance. | - |
| 6.3.1.8 | x:ClassModifier obeys class rules. | Not Implemented | x:ClassModifier is rejected. | Generated View visibility follows the View API contract. | - |
| 6.3.1.9 | x:TypeArguments obeys generic-type rules. | Not Implemented | x:TypeArguments is rejected. | Generic object construction is excluded. | - |
| 6.3.1.10 | x:FieldModifier obeys named-field rules. | Not Implemented | x:FieldModifier is rejected. | Names compile to private stable connections instead of CLR fields. | - |
| 6.3.2 | Enforce member validity constraints. | Partial | Value type, ownership, attached and unique-name rules are checked for the profile schema. | Read-only, key and general assignability rules are excluded. | PC-DUP-01 |
| 6.3.2.1 | Values are appropriate for the member type. | Partial | The compiler pipeline performs scalar conversion and structural validation with source spans. | MoonBit compiler performs final business member and target-type checking. | CG-VIEW-01, INVENTORY-01, SURVIVORS-01 |
| 6.3.2.2 | Non-attached member is owned by element type. | Conformant | Unknown members fail during parse. | None. | PC-INFOSET-01 |
| 6.3.2.3 | Attached member target type is valid. | Partial | Owner and `is_attached` are checked. | General type assignability is not modeled. | PC-INFOSET-01 |
| 6.3.2.4 | Text for non-text member matches its text syntax. | Partial | Bool, Int, Double, box-list and supported UI enum literals become typed constants during ViewIR lowering. Emitters do not parse their authored text again. | Other abstract text-syntax shapes are outside the current generated tree contract. | VI-IR-01, CG-VIEW-01, INVENTORY-01 |
| 6.3.2.5 | Read-only member use is restricted. | Not Applicable | Read-only schema members are absent. | Shared tree mutations expose only writable contract fields. | - |
| 6.3.2.6 | Names are unique within a namescope. | Conformant | Duplicate `Id`/`x:Name` fails; component scopes are isolated and projected content retains caller scope. | None for Profile 1 namescopes. | PC-DUP-01 |
| 6.3.2.7 | x:Key follows dictionary rules. | Not Implemented | x:Key/resource dictionaries are excluded. | `KeyPath` is a Selene compiler control member. | - |
| 6.3.2.8 | x:FieldModifier follows field rules. | Not Implemented | Generated fields are excluded. | See 6.3.1.10. | - |
| 6.3.2.9 | XamlType values/type names resolve to valid types. | Partial | `{x:Type}` uses namespace maps and schema registry. | Compiler retains a build-time symbolic type name. | PC-ME-03 |
| 6.3.3 | Non-normative member-node notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 6.4 | Text node has text value and parent member. | Conformant | Text and exact source span are retained under a member. | Parent relation is structural. | PC-INFOSET-01 |
| 6.4.1 | Enforce text-node constraints. | Conformant | Text can be created only while processing a valid content/property member. | None. | PC-INFOSET-01 |
| 6.4.1.1 | Text-node properties have specified types. | Conformant | Public fields are concrete MoonBit types. | None. | PC-INFOSET-01 |
| 6.4.2 | Non-normative text-node notes. | Not Applicable | Informational section. | No normative requirement. | - |

## Section 7 - Intrinsic Schema Information Items

| Spec | Requirement summary | Status | Selene behavior | Deviation rationale | Test ID |
| --- | --- | --- | --- | --- | --- |
| 7 | Supply intrinsic x: and XML schema items. | Partial | Standard x namespace, `x:Null`, `x:Reference`, `x:Type`, selected directives including `x:Class`, and `xml:space` are implemented. | Remaining intrinsic objects/directives are excluded. | PC-ME-03 |
| 7.1 | Define intrinsic schema items. | Partial | Fixed intrinsic parser/schema entries are installed by `selene_xaml_schemas`. | The full intrinsic schema is not exposed. | PC-ME-03 |
| 7.1.1 | Define the standard `x:` schema. | Partial | Uses `http://schemas.microsoft.com/winfx/2006/xaml`. | Selected items only. | PC-INFOSET-01 |
| 7.1.2 | Define the XML namespace schema. | Partial | `xml:space` and the XML namespace URI are recognized. | `xml:lang` and `xml:base` are not mapped. | PC-SPACE-01 |
| 7.2.1 | x:ArrayExtension. | Not Implemented | Rejected as unknown intrinsic type. | Arrays enter generated View APIs through typed business state. | - |
| 7.2.2 | x:StaticExtension. | Not Implemented | Rejected as unknown intrinsic type. | Static member access is excluded. | - |
| 7.2.3 | x:TypeExtension. | Partial | `{x:Type}` parses and resolves namespace-qualified symbolic names. | No general XamlType object is produced. | PC-ME-03 |
| 7.2.4 | x:NullExtension. | Partial | `{x:Null}` is retained as a typed infoset value. | Nullable target checking and generated `None` emission are not in the automated View package subset. | PC-ME-03 |
| 7.2.5 | x:ReferenceExtension. | Partial | `{x:Reference name}` is retained with its target name. | Generated node-connection resolution is not in the automated View package subset. | PC-ME-03 |
| 7.2.6 | x:Object. | Not Implemented | General intrinsic object construction is excluded. | Published View APIs use concrete business and UI tree types. | - |
| 7.2.7 | x:String. | Not Implemented | x:String object elements are excluded. | Text syntax maps directly to MoonBit strings. | CG-VIEW-01 |
| 7.2.8 | x:Char. | Not Implemented | Intrinsic char object is excluded. | No Selene UI member requires it. | - |
| 7.2.9 | x:Single. | Not Implemented | Intrinsic single object is excluded. | Selene uses Double. | - |
| 7.2.10 | x:Double. | Partial | Double text conversion is implemented for generated UI members. | x:Double object elements are excluded. | INVENTORY-01 |
| 7.2.11 | x:Byte. | Not Implemented | Intrinsic byte object is excluded. | Not required by vocabulary. | - |
| 7.2.12 | x:Int16. | Not Implemented | Intrinsic Int16 object is excluded. | Selene uses MoonBit Int. | - |
| 7.2.13 | x:Int32. | Partial | Integer text conversion is implemented for generated UI members. | x:Int32 object elements are excluded. | INVENTORY-01 |
| 7.2.14 | x:Int64. | Not Implemented | Intrinsic Int64 object is excluded. | Not required by vocabulary. | - |
| 7.2.15 | x:Decimal. | Not Implemented | Decimal is excluded. | Game UI uses Double. | - |
| 7.2.16 | x:Uri. | Partial | Namespace/source/image paths are strings. | No intrinsic URI object or general URI validation. | PC-INFOSET-01 |
| 7.2.17 | x:Timespan. | Not Implemented | Intrinsic timespan is excluded. | Transition Duration/Delay are seconds as Double. | - |
| 7.2.18 | x:Boolean. | Partial | Boolean literals and typed bindings are implemented for generated UI members. | x:Boolean object elements are excluded. | INVENTORY-01, SURVIVORS-01 |
| 7.2.19 | x:Array. | Not Implemented | Intrinsic array construction is excluded. | `ItemsControl` consumes typed business arrays through generated state. | CG-VIEW-01, INVENTORY-01, SURVIVORS-01 |
| 7.2.20 | x:XamlType. | Not Implemented | No published XamlType object exists. | Symbolic `{x:Type}` is sufficient for Profile 1 compilation. | - |
| 7.2.21 | x:XamlEvent. | Not Implemented | Selene action attributes generate a view-specific action enum. | The XamlEvent member model is excluded. | CG-VIEW-01 |
| 7.2.22 | x:MarkupExtension. | Partial | Dedicated parser and five built-in evaluators are provided. | User-defined markup extensions are excluded. | PC-ME-01 |
| 7.2.23 | x:Code. | Not Implemented | Inline code is rejected. | Arbitrary scripts are explicitly excluded. | - |
| 7.2.24 | x:XData. | Not Implemented | XML data blocks are rejected. | XML embedding is explicitly excluded. | - |
| 7.3.1 | x:Items directive. | Partial | Represented in infoset. | General collection construction is not evaluated. | PC-DIRECTIVE-01 |
| 7.3.2 | x:PositionalParameters directive. | Partial | Parsed and retained as a directive member. | Arbitrary constructors are not evaluated. | PC-DIRECTIVE-01 |
| 7.3.3 | x:Initialization directive. | Partial | Parsed and retained as a directive member. | General initialization semantics are excluded. | PC-DIRECTIVE-01 |
| 7.3.4 | x:Name directive. | Conformant | Creates a compiler namescope entry and stable node key; duplicate authored names and normalized-key collisions fail before source emission. | Same scope slot as Selene `Id`. | PC-DUP-01, CG-VIEW-01, CG-KEY-01 |
| 7.3.5 | x:Key directive. | Not Implemented | Rejected. | Resource dictionaries are excluded. | - |
| 7.3.6 | x:Uid directive. | Not Implemented | Rejected. | Localization UID metadata is excluded. | - |
| 7.3.7 | x:Class directive. | Partial | Retained as a literal root directive and used to name the generated View identity. | CLR class construction and inheritance are excluded. | PC-DIRECTIVE-02, VI-IR-01 |
| 7.3.8 | x:Subclass directive. | Not Implemented | Rejected. | Generated View types do not model CLR inheritance. | - |
| 7.3.9 | x:ClassModifier directive. | Not Implemented | Rejected. | Generated View visibility follows the View API contract. | - |
| 7.3.10 | x:FieldModifier directive. | Not Implemented | Rejected. | Names compile to private stable connections. | - |
| 7.3.11 | x:TypeArguments directive. | Not Implemented | Rejected. | Generic construction is excluded. | - |
| 7.3.12 | x:DirectiveChildren. | Not Implemented | Rejected. | Excluded intrinsic construction path. | - |
| 7.3.13 | xml:lang directive. | Not Implemented | Rejected/unknown for mapping. | Localization is application data. | - |
| 7.3.14 | xml:space directive. | Conformant | `default` collapses whitespace; `preserve` retains authored text and inherits. | None. | PC-SPACE-01 |
| 7.3.15 | xml:base directive. | Not Implemented | Not mapped. | Source URI is supplied explicitly to `parse_xaml`. | - |
| 7.3.16 | x:Arguments directive. | Not Implemented | Rejected. | Arbitrary constructors are excluded. | - |
| 7.3.17 | x:FactoryMethod directive. | Not Implemented | Rejected. | Factory methods are excluded. | - |
| 7.3.18 | ArrayExtension.Items member. | Not Implemented | ArrayExtension is excluded. | See 7.2.1. | - |
| 7.3.19 | ArrayExtension.Type member. | Not Implemented | ArrayExtension is excluded. | See 7.2.1. | - |
| 7.3.20 | StaticExtension.Member. | Not Implemented | StaticExtension is excluded. | See 7.2.2. | - |
| 7.3.21 | TypeExtension.Type. | Partial | `{x:Type}` accepts a positional/named symbolic type. | Result is symbolic. | PC-ME-03 |
| 7.3.22 | TypeExtension.TypeName. | Partial | Namespace-qualified type text is parsed. | Result is symbolic. | PC-ME-03 |
| 7.3.23 | ReferenceExtension.Name. | Partial | Positional or named reference text is parsed and retained. | Generated node-connection resolution is not in the automated View package subset. | PC-ME-03 |
| 7.4.1 | x:Char text syntax. | Not Implemented | Excluded. | Not required by vocabulary. | - |
| 7.4.2 | x:Single text syntax. | Not Implemented | Excluded. | Selene uses Double. | - |
| 7.4.3 | x:Double text syntax. | Partial | MoonBit strict Double parsing validates generated numeric literals. | Intrinsic object element is excluded. | INVENTORY-01 |
| 7.4.4 | x:Byte text syntax. | Not Implemented | Excluded. | Not required. | - |
| 7.4.5 | x:Int16 text syntax. | Not Implemented | Excluded. | Not required. | - |
| 7.4.6 | x:Int32 text syntax. | Partial | MoonBit strict Int parsing validates generated integer literals. | Intrinsic object element is excluded. | INVENTORY-01 |
| 7.4.7 | x:Int64 text syntax. | Not Implemented | Excluded. | Not required. | - |
| 7.4.8 | x:Decimal text syntax. | Not Implemented | Excluded. | Not required. | - |
| 7.4.9 | x:Uri text syntax. | Not Implemented | URI values remain strings. | General URI conversion is excluded. | - |
| 7.4.10 | x:Timespan text syntax. | Not Implemented | Duration/Delay use Double seconds. | No intrinsic timespan. | - |
| 7.4.11 | x:Boolean text syntax. | Partial | Generated literals accept `true` and `false`; typed bindings use MoonBit `Bool`. | Numeric aliases are outside the generated syntax. | INVENTORY-01 |
| 7.4.12 | x:XamlType text syntax. | Partial | QName resolution is used by `{x:Type}`. | No published XamlType object exists. | PC-ME-03 |
| 7.4.13 | xml:space text syntax. | Conformant | Only `default` and `preserve` are accepted. | None. | PC-SPACE-01 |
| 7.4.14 | x:XamlEvent text syntax. | Not Implemented | XamlEvent is excluded. | Action attribute strings become generated enum cases and stable-key routes. | CG-VIEW-01 |
| 7.4.15 | x:NameReference text syntax. | Partial | Reference names are parsed in the authoring namespace scope. | Generated component/caller namescope resolution is not in the automated View package subset. | PC-ME-03 |
| 7.4.16 | x:TypeArguments text syntax. | Not Implemented | Generic types are excluded. | See 7.3.11. | - |
| 7.4.17 | x:FactoryMethod text syntax. | Not Implemented | Factory methods are excluded. | See 7.3.17. | - |
| 7.5 | Define intrinsic constructors. | Partial | Extension positional/named argument grammar is parsed. | General constructor infoset is absent. | PC-ME-01 |
| 7.5.1 | StaticExtension string constructor. | Not Implemented | StaticExtension is excluded. | See 7.2.2. | - |
| 7.5.2 | TypeExtension string constructor. | Partial | A positional type name is accepted. | Symbolic result only. | PC-ME-03 |
| 7.5.3 | ReferenceExtension string constructor. | Conformant | A positional reference name is accepted. | None for Selene references. | PC-ME-03 |

## Section 8 - Creating a Xaml Information Set from XML

| Spec | Requirement summary | Status | Selene behavior | Deviation rationale | Test ID |
| --- | --- | --- | --- | --- | --- |
| 8 | Map namespace-aware XML into a Xaml infoset. | Partial | `xml-mbt NamespaceReader` drives deterministic object/member/text mapping. | Profile 1 implements the selected schema and intrinsic subset. | PC-DOC-01 |
| 8.1 | Define behavior when Xaml schemas are unavailable. | Conformant | Unknown non-ignorable namespace/type/member produces an error diagnostic. | No schema-less raw object mapping mode. | PC-UNKNOWN-01 |
| 8.2 | Report processing errors. | Conformant | `XamlError::Diagnostic` contains stable code, message, severity and exact source span. | None. | PC-UNKNOWN-01 |
| 8.3 | Apply markup compatibility processing. | Partial | Common `mc:Ignorable` prefixes filter design-time attributes/elements. | `ProcessContent`, `AlternateContent`, preservation and full MC vocabulary are excluded. | PC-INFOSET-01 |
| 8.3.1 | Raw mode consumes XML without MC preprocessing. | Partial | Non-ignorable input follows raw namespace-aware processing. | No public mode switch. | PC-INFOSET-01 |
| 8.3.2 | Preprocessed mode accepts MC-preprocessed input. | Partial | Ignorable nodes are filtered in the parser. | Only common ignorable behavior is implemented. | PC-INFOSET-01 |
| 8.3.3 | Define schema subsumption behavior. | Not Implemented | Namespace schemas are exact URI registrations. | Version/subsumption relationships are excluded. | - |
| 8.4 | Interpret XML Information Set references. | Conformant | XML element, attribute, namespace, character and source-span events are consumed. | Comments and PIs are intentionally ignored as specified by the profile. | PC-XML-01 |
| 8.5 | Define terms used by mapping rules. | Partial | Dotted names, collapsible whitespace and authoritative registry concepts are implemented. | Formal definitions are represented operationally. | PC-XML-01 |
| 8.5.1 | Define DottedXamlName. | Conformant | Exactly one dot separates owner and member; malformed dotted names fail. | None. | PC-INFOSET-01 |
| 8.5.2 | Define collapsible whitespace characters. | Conformant | Space, tab, CR and LF collapse outside `xml:space=preserve`. | None. | PC-SPACE-01 |
| 8.5.3 | Define linefeed collapsing characters. | Conformant | CR/LF participate in whitespace normalization. | None. | PC-SPACE-01 |
| 8.5.4 | Define authoritative schema selection. | Conformant | `XamlSchemaRegistry` is the authoritative mapping supplied to `parse_xaml`. | No ambient/global schema inference. | PC-SCHEMA-01 |
| 8.6 | Apply document processing rules in order. | Partial | Namespace-aware recursive descent applies Profile 1 rules with atomic failure. | Excluded intrinsic/schema capabilities remain unavailable. | PC-DOC-01 |
| 8.6.1-a | Accept UTF-8 XML documents. | Conformant | Parser and generator file input use strict UTF-8 decoding. | None. | PC-ENC-01 |
| 8.6.1-b | Accept an optional UTF-8 BOM. | Conformant | File-input decoding uses `ignore_bom=true`. | None. | PC-ENC-01 |
| 8.6.1-c | Accept UTF-16 XML documents. | Partial | UTF-16 byte streams are rejected as `InvalidUtf8`. | Profile 1 deliberately supports UTF-8 files only. | PC-ENC-02 |
| 8.6.1-d | Reject DTDs. | Conformant | Any DocType event fails immediately before object mapping. | None. | PC-DTD-01 |
| 8.6.1-e | Reject undeclared/custom entity processing. | Conformant | DTDs are forbidden; XML invalid-entity errors become XAML diagnostics. | Only predefined/numeric XML references remain legal. | PC-DTD-01 |
| 8.6.1-f | Require one document element and legal exterior content. | Conformant | Missing/multiple roots and non-whitespace exterior text fail. | None. | PC-DOC-01 |
| 8.6.2-a | Create an Object Node for an object element. | Conformant | Resolved element QName selects a schema type and creates an object node. | None. | PC-INFOSET-01 |
| 8.6.2-b | Carry namespace declarations into namespace nodes/scope. | Conformant | Authored declarations are retained; inherited maps resolve extensions. | None. | PC-INFOSET-01 |
| 8.6.2-c | Reject unknown non-ignorable object namespaces/types. | Conformant | Missing schema/type raises SX1103. | None. | PC-UNKNOWN-01 |
| 8.6.2-d | Ignore comments and processing instructions. | Conformant | Neither creates infoset nodes. | None. | PC-XML-01 |
| 8.6.2.1 | Non-normative object-creation notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 8.6.3-a | Map a normal XML attribute to a member node. | Conformant | Unqualified attributes bind to current type members. | None. | PC-INFOSET-01 |
| 8.6.3-b | Map dotted attributes to attached members. | Conformant | Owner schema and attachable flag are required. | General assignability is simplified to exact registered owner. | PC-INFOSET-01 |
| 8.6.3-c | Map intrinsic x: attributes to directive members. | Partial | Name, Class, Items, Initialization and PositionalParameters are represented. | Other directives are rejected. | PC-DIRECTIVE-01, PC-DIRECTIVE-02 |
| 8.6.3-d | Reject duplicate attribute/member assignment. | Conformant | Duplicate attribute/property-element identities fail. | None. | PC-DUP-01 |
| 8.6.3.1 | Non-normative attribute notes. | Not Applicable | Informational section. | No normative requirement. | - |
| 8.6.4-a | Convert escaped `{}` attribute text to literal text. | Conformant | Leading `{}` removes extension interpretation. | None. | PC-ME-02 |
| 8.6.4-b | Convert `{...}` attribute text to a markup extension. | Conformant | Dedicated grammar creates `XamlMarkupExtension`. | Only registered built-in evaluators execute. | PC-ME-01 |
| 8.6.4-c | Convert ordinary attribute text through member text syntax. | Partial | Infoset retains text; View source emission validates supported UI literals, including `Auto`, pixel and percent layout values, with the original span. | MoonBit compiler performs final business member and target-type checking. | CG-VIEW-01, CG-LAYOUT-01, INVENTORY-01 |
| 8.6.5-a | Map property elements to member nodes. | Conformant | `Owner.Member` child elements collect text/object values, including nested VisualState groups, setters and transitions. | Exact owner name is required for non-attached property elements. | PC-INFOSET-01, VI-IR-04 |
| 8.6.5-b | Enforce property-element cardinality and duplicates. | Conformant | Singular members reject multiple values and repeated assignments. | None. | PC-DUP-01 |
| 8.6.6-a | Map child object elements through the content member. | Conformant | Schema content member receives ordered child objects. | None. | PC-INFOSET-01 |
| 8.6.6-b | Map text content through the content member. | Conformant | Normalized text becomes an ordered `XamlTextNode`. | None. | PC-INFOSET-01 |
| 8.6.6-c | Collapse default whitespace. | Conformant | Runs collapse to one separator; boundary-only whitespace is dropped. | None. | PC-SPACE-01 |
| 8.6.6-d | Preserve `xml:space=preserve` text and inheritance. | Conformant | Exact text is retained until `default` resets behavior. | None. | PC-SPACE-01 |
| 8.6.7 | Create an object/value from markup extension attribute syntax. | Partial | Extensions are typed AST values and five built-ins evaluate. | User-defined extensions and general constructor invocation are excluded. | PC-ME-01 |
| 8.6.7.1-a | Parse extension type, positional and named arguments. | Conformant | Quoting, nesting, commas, equals and namespace prefixes are parsed. | Custom bracket characters are excluded. | PC-ME-01 |
| 8.6.7.1-b | Detect malformed/unbalanced extension syntax. | Conformant | Invalid grammar raises span-bearing SX120x diagnostics. | None. | PC-ME-02 |
| 8.6.7.2-a | Convert x:Null, x:Reference and x:Type extensions. | Partial | All three built-ins evaluate in Profile 1. | x:Type result is symbolic. | PC-ME-03 |
| 8.6.7.2-b | Convert vocabulary-specific markup extensions. | Partial | `ui:Binding` resolves to typed computed-ViewModel steps, dependencies and ordinary or VisualState setter targets in ViewIR. | `ui:TemplateBinding` is parsed, while generated component props are outside the current automated subset; arbitrary expressions and runtime path interpretation are excluded. | VI-IR-01, VI-IR-03, VI-IR-04, CG-VIEW-01 |
| 8.6.8-a | Look up ordinary members on the object type. | Conformant | Exact member-map lookup; unknown member fails. | None. | PC-INFOSET-01 |
| 8.6.8-b | Look up attached members on their owner type. | Conformant | Exact owner/member lookup plus attached flag. | General assignability metadata is absent. | PC-INFOSET-01 |
| 8.6.9 | Convert XML namespace mappings into Xaml namespace nodes. | Conformant | Prefix/default mappings are retained with exact source spans and used by QName resolution. | None. | PC-INFOSET-01 |
