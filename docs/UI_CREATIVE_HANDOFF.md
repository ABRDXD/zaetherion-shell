# UI and creative direction — handoff to Claude A

15 November 2026. Applies to every FART / ZÆTHERION surface, including the island,
launcher, rooms, settings, transient states and transitions.

The owner's instruction: **“SLOP, MEDIOCRITY, SAMEYNESS ISNT ACCEPTED IN THIS PROJECT.”**
Functional completeness alone does not meet the design standard. A surface must have
a deliberate composition, recognisable character and convincing interaction. More
decoration does not establish quality either.

## Authority and continuity

This handoff consolidates the owner's approved direction and gives practical critique
criteria. It does not approve a new visual direction, backend, feature or interaction.
Follow the latest owner decision when older design documents disagree. In particular:

- [DECISIONS](DECISIONS.md): Z146 separates form from mode; Z153/Z155 describe the
  Fluid island and shared style authority; Z157 keeps surfaces connected to the island;
  Z196–Z199 establish the astrophysical language and DMS boundary.
- Z199 updates the launcher's apps to cold planets. Z200 supersedes the earlier island
  dwell durations: timed faces last at most one second, with the documented exceptions.
- [Angular design system](fart/DESIGN_SYSTEM.md), [montage](fart/MONTAGE.md),
  [motion cues](fart/CUES.md) and [Overdrive](fart/OVERDRIVE.md) preserve the existing
  design vocabulary. Their Angular geometry rules are not a mandate to flatten Fluid
  into the same presentation.
- Confluence is approved. Continue it; do not restart the design exploration or Phase 1.
  [Home evidence](captures/fluid-home/README.md) and the captures in
  [the Media checkpoint](captures/fluid-phase2/) show implemented progress, not a finished
  design for every room or the surrounding shell.

## Preserve two identities and two modes

| | Angular | Fluid / Confluence |
|---|---|---|
| Character | Sharp, aggressive, directional, experimental | Continuous, composed, spacious, architecturally curved |
| Composition | Strong cuts, intentional tension, expressive typography and directional hierarchy | Connected matte surfaces, deliberate negative space, elegant proportions and restrained curves |
| Silent | Identity remains legible without spectacle; immediate interaction | Calm spatial structure and clear hierarchy; immediate interaction |
| Overdrive | Existing expressive spatial and astrophysical language | The same Confluence system with expressive spatial transitions, preserving clarity and responsiveness |

Fluid needs its own compositions. Rounding Angular controls cannot deliver it. Conversely,
Fluid work must preserve the Angular visuals. Silent and Overdrive share each form's
underlying identity; neither mode is an excuse for a second unrelated component system.

## Make the concept do useful work

Before implementing a new surface, write a few sentences answering:

1. What is the user's primary action or most important reading here?
2. What organising idea expresses it, and why does that idea belong to this surface?
3. Where does attention begin, what is secondary, and what remains quiet?
4. What changes on input, what settles afterwards, and what survives reduced motion?

Then build against those answers. Use scale, placement, alignment, typography, density
and negative space before adding effects. Give the surface a dominant relationship:
for example, a primary reading with supporting context, or an active selection within
a spatial system. Do not give every value and action equal visual weight.

The approved star chart and cold edge-on workspace transit are useful precedents:
selection, rank, depth, lighting and movement express relationships. They are not just
astronomy illustrations placed behind buttons. Preserve the mature sense of scale and
restraint in the owner's “large cold universe” direction. A quiet, precise composition
can be more distinctive than a busy one.

Use the approved scale hierarchy where applicable: black hole = overview; planetary
systems = rooms/workspaces; planets = apps/windows; moons = actions. Do not paste an
orrery onto every task. Give each surface a composition suited to its information while
keeping the shared visual language coherent. Keep familiar actions discoverable through
readable labels, focus and feedback; the metaphor must support their use.

## Reasons to reject a draft

- An interchangeable dashboard: equal cards, identical spacing, a generic heading and
  the same action row repeated everywhere without regard to the room's purpose.
- A “premium” treatment made only from gradients, glow, shadows or extra animation.
- Glassmorphism, excessive blur, glossy surfaces, generic Material layouts, oversized
  pills or endless floating cards in Confluence. Approved icon assets are a separate matter.
- Recolouring, rounding or swapping icons while leaving the underlying composition generic.
- Applying the same orbit, decorative grid, astronomical label or hero treatment to every room.
- Arbitrary asymmetry, illegible theatrical type, tiny controls or hidden actions justified
  as experimental. Preserve intentional symmetry where the approved design requires it.
- A strong empty mock-up that collapses with real-length labels, many results, unavailable
  services, a changed palette or a visible keyboard focus indicator.
- Motion that delays input, fights rapid reversal, distracts from reading, or keeps expensive
  hidden work alive. Respect approved existing idle effects; add none merely to fill silence.

Reuse semantic controls and tokens for consistency. Reuse an entire room composition only
when its information and interaction call for it. Distinctness is not an excuse
to make the same action behave differently from room to room.

## Critique the implementation, not just the description

Inspect actual nested Hyprland captures at the intended 1920×1080 desktop and roughly
1360×860 panel. Review the changed surface with realistic synthetic content, keyboard
focus, long text, sparse/empty data, unavailable state, and AMOLED contrast. Exercise the
relevant Silent/Overdrive and reduced-motion states. Inspect motion as a sequence;
a still frame cannot establish its timing or responsiveness.

Ask: what is distinctive here besides the colour? Is the main action obvious? Does the
composition remain coherent without decorative effects? Does each effect explain a
state or reinforce the intended character? Can the controls be used comfortably?
What specific visible weakness should be corrected before calling this finished?

For an undecided direction, alternatives should differ in composition and
interaction, not merely palette or corner radius. Keep that exploration bounded. For an
already approved direction, implement and refine it rather than asking the owner to choose again.
These critique prompts do not introduce a new blanket approval gate.

## Protect the working product

- Reuse DMS services and commands through the existing adapters (Z198). Creativity belongs
  in the presentation and interaction; do not duplicate backends to support a visual idea.
- Preserve `island.form` → `Design.form`. Palette and mode remain independent of style.
  Persistent room controllers own essential state; replaceable views consume it.
  Rapid switching must retain state and predictable focus without multiplying leases.
- Home and Media have Confluence presentations. Other rooms and shared framing remain
  incomplete. Existing Overdrive effects work; full Fluid-specific transitions remain pending.
  Do not report a global selector as completion of the entire Fluid control centre.
- Follow [budgets](BUDGETS.md). Stop unnecessary hidden rendering; release resources.
  Measure before claiming 144 Hz performance. A 60 Hz nested capture proves no such claim.
- Main is live and other agents work concurrently. Read fresh Git state, use an isolated
  worktree for UI implementation, integrate and test there, then follow the existing merge
  and reload procedure. Preserve the owner's current settings and other agents' changes.
  Use fixtures and nested Hyprland for visual work; never actuate real services for a screenshot.

**Next implementation milestone:** Confluence Performance, followed by the shared Fluid
shell framing. Reuse its existing semantic services; develop a composition appropriate to
the readings and their relationships. No new Performance visual concept is approved by
this handoff. Hand back working code, inspected evidence, remaining weaknesses and a
precise next task—not a claim that a plausible first draft is finished.
