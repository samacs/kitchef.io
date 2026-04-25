// Adds `<turbo-stream action="morph" target="...">` so a server response can
// merge HTML diff-by-diff into an existing element instead of swapping it.
// The default `replace` blows away the target subtree, which destroys the
// caret position and any focus the operator had — bad for autosave-driven
// forms where the user is mid-typing when the response lands.
//
// Behavior mirrors Turbo's built-in `replace`: by default we morph the
// target's children (so the wrapper element keeps its identity). Pass
// `children="false"` on the stream tag to morph the wrapper itself.
//
// We attach to the runtime `window.Turbo` rather than importing named
// exports because the precompiled `turbo.min.js` only exposes the
// default-bundle global — it doesn't surface `StreamActions` /
// `morphChildren` as ESM named exports through the importmap.
const register = () => {
  const Turbo = window.Turbo
  if (!Turbo?.StreamActions) {
    // Turbo not ready yet — try again on the next tick.
    setTimeout(register, 0)
    return
  }
  if (Turbo.StreamActions.morph) return // already registered

  Turbo.StreamActions.morph = function () {
    this.targetElements.forEach((target) => {
      const incoming = this.templateContent
      const morphChildrenOnly = this.getAttribute("children") !== "false"

      if (morphChildrenOnly) {
        Turbo.morphChildren(target, incoming)
      } else {
        const wrapper = target.cloneNode(false)
        wrapper.appendChild(incoming)
        Turbo.morphElements(target, wrapper)
      }
    })
  }
}

register()
