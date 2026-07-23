///|
/// Returns a mask for the longest increasing subsequence of retained sibling
/// indices. Negative entries represent newly mounted or reparented nodes and
/// are excluded from the subsequence.
pub fn retained_lis_mask(previous_indices : Array[Int]) -> Array[Bool] {
  let retained = Array::make(previous_indices.length(), false)
  let tails : Array[Int] = []
  let predecessors = Array::make(previous_indices.length(), -1)
  for index, value in previous_indices {
    if value < 0 {
      continue
    }
    let mut low = 0
    let mut high = tails.length()
    while low < high {
      let middle = low + (high - low) / 2
      if previous_indices[tails[middle]] < value {
        low = middle + 1
      } else {
        high = middle
      }
    }
    if low > 0 {
      predecessors[index] = tails[low - 1]
    }
    if low == tails.length() {
      tails.push(index)
    } else {
      tails[low] = index
    }
  }
  if tails.is_empty() {
    return retained
  }
  let mut cursor = tails[tails.length() - 1]
  while cursor >= 0 {
    retained[cursor] = true
    cursor = predecessors[cursor]
  }
  retained
}

///|
/// Produces the minimal property mutations for two keyed node specifications.
fn diff_node_specs(
  previous : NodeSpec,
  desired : NodeSpec,
  mutations : Array[TreeMutation],
) -> Unit {
  let precise_previous = {
    ..previous,
    parent: desired.parent,
    text: desired.text,
    source: desired.source,
    active: desired.active,
    enabled: desired.enabled,
    style: {
      ..previous.style,
      background: desired.style.background,
      top: desired.style.top,
    },
  }
  if precise_previous != desired {
    mutations.push(TreeMutation::Update(desired))
    return
  }
  if previous.text != desired.text {
    mutations.push(TreeMutation::SetText(desired.key, desired.text))
  }
  if previous.source != desired.source {
    mutations.push(TreeMutation::SetSource(desired.key, desired.source))
  }
  if previous.style.background != desired.style.background {
    mutations.push(
      TreeMutation::SetBackground(desired.key, desired.style.background),
    )
  }
  if previous.active != desired.active {
    mutations.push(TreeMutation::SetActive(desired.key, desired.active))
  }
  if previous.enabled != desired.enabled {
    mutations.push(TreeMutation::SetEnabled(desired.key, desired.enabled))
  }
  if previous.style.top != desired.style.top {
    mutations.push(TreeMutation::SetTop(desired.key, desired.style.top))
  }
}

///|
/// Reconciles two keyed node specification arrays into an atomic mutation batch.
///
/// Property-only updates use an index-aligned fast path. Structural updates
/// retain the longest increasing subsequence of each sibling group so keyed
/// entities move only when their relative order requires it.
pub fn reconcile_specs(
  previous : Array[NodeSpec],
  desired : Array[NodeSpec],
) -> Array[TreeMutation] {
  if previous == desired {
    return []
  }
  let mutations : Array[TreeMutation] = []
  let mut structure_changed = previous.length() != desired.length()
  if !structure_changed {
    for index, spec in previous {
      let candidate = desired[index]
      if spec.key != candidate.key || spec.parent != candidate.parent {
        structure_changed = true
        break
      }
    }
  }
  if !structure_changed {
    for index, spec in desired {
      diff_node_specs(previous[index], spec, mutations)
    }
    return mutations
  }
  let previous_by_key : Map[String, NodeSpec] = Map([])
  let desired_by_key : Map[String, NodeSpec] = Map([])
  for spec in previous {
    previous_by_key[spec.key] = spec
  }
  for spec in desired {
    desired_by_key[spec.key] = spec
  }
  let previous_index_by_key : Map[String, Int] = Map([])
  let previous_sibling_counts : Map[String, Int] = Map([])
  let current_children : Map[String, Array[String]] = Map([])
  let current_parent_by_key : Map[String, String] = Map([])
  for spec in previous {
    let parent = spec.parent.unwrap_or("")
    let sibling_index = previous_sibling_counts.get(parent).unwrap_or(0)
    previous_index_by_key[spec.key] = sibling_index
    previous_sibling_counts[parent] = sibling_index + 1
    if desired_by_key.contains(spec.key) {
      current_children.get_or_init(parent, fn() { [] }).push(spec.key)
      current_parent_by_key[spec.key] = parent
    }
  }
  let desired_children : Map[String, Array[String]] = Map([])
  let desired_parents : Array[String] = []
  let seen_parents : Map[String, Bool] = Map([])
  for spec in desired {
    match spec.parent {
      Some(parent) => {
        if !seen_parents.contains(parent) {
          seen_parents[parent] = true
          desired_parents.push(parent)
        }
        desired_children.get_or_init(parent, fn() { [] }).push(spec.key)
      }
      None => ()
    }
  }
  for spec in previous {
    if !desired_by_key.contains(spec.key) {
      let removed_root = match spec.parent {
        Some(parent) => desired_by_key.contains(parent)
        None => true
      }
      if removed_root {
        mutations.push(TreeMutation::Remove(spec.key))
      }
    }
  }
  for spec in desired {
    if !previous_by_key.contains(spec.key) {
      mutations.push(TreeMutation::Mount(spec))
      match spec.parent {
        Some(parent) => {
          current_children.get_or_init(parent, fn() { [] }).push(spec.key)
          current_parent_by_key[spec.key] = parent
        }
        None => ()
      }
    }
  }
  for parent in desired_parents {
    let desired_order = desired_children[parent]
    let previous_indices : Array[Int] = []
    for key in desired_order {
      match previous_by_key.get(key) {
        Some(old) if old.parent == Some(parent) =>
          previous_indices.push(previous_index_by_key[key])
        _ => previous_indices.push(-1)
      }
    }
    let stable_positions = retained_lis_mask(previous_indices)
    let mut desired_index = desired_order.length() - 1
    while desired_index >= 0 {
      if previous_indices[desired_index] >= 0 && stable_positions[desired_index] {
        desired_index -= 1
        continue
      }
      let key = desired_order[desired_index]
      let current_parent = current_parent_by_key.get(key).unwrap_or(parent)
      let current_siblings = current_children.get_or_init(current_parent, fn() {
        []
      })
      let mut current_index = -1
      for index, sibling in current_siblings {
        if sibling == key {
          current_index = index
          break
        }
      }
      if current_index >= 0 {
        ignore(current_siblings.remove(current_index))
      }
      let destination = current_children.get_or_init(parent, fn() { [] })
      let target_index = if desired_index + 1 < desired_order.length() {
        let anchor = desired_order[desired_index + 1]
        let mut anchor_index = destination.length()
        for index, sibling in destination {
          if sibling == anchor {
            anchor_index = index
            break
          }
        }
        anchor_index
      } else {
        destination.length()
      }
      if current_parent != parent || current_index != target_index {
        mutations.push(TreeMutation::Move(key, parent, target_index))
      }
      destination.insert(target_index, key)
      current_parent_by_key[key] = parent
      desired_index -= 1
    }
  }
  for spec in desired {
    match previous_by_key.get(spec.key) {
      Some(old) => diff_node_specs(old, spec, mutations)
      None => ()
    }
  }
  mutations
}
