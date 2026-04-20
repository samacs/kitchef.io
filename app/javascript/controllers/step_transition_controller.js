import { Controller } from "@hotwired/stimulus"

// Fades-in the current onboarding step on connect. The markup starts
// with the step at `opacity:0, translate-y-2`; we wait one frame then
// remove the classes so the transition runs. Keeps the stepper itself
// still so the progress bar reads as continuous across navigations.
export default class extends Controller {
  static targets = ["step"]

  connect() {
    if (!this.hasStepTarget) return

    const step = this.stepTarget
    step.classList.add("opacity-0", "translate-y-2", "transition-[opacity,transform]", "duration-300", "ease-out")

    // Two rAFs so the initial state actually paints before we transition.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      step.classList.remove("opacity-0", "translate-y-2")
    }))
  }
}
