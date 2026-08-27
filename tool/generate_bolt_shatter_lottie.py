#!/usr/bin/env python3
"""Generates assets/animations/bolt_shatter_stars_{0,2,3,4,5}.json.

Multi-phase "lightning shatters into stars" animation, hand-authored
(procedurally generated) with the `lottie` python library's own object model
(https://pypi.org/project/lottie/) so the exported JSON is guaranteed to
match the Bodymovin schema exactly, rather than being typed out as raw JSON.

Because the final "ready" resting state can show 0, 2, 3, 4, or 5 stars
(standing in for "how many results came back" from a future API -- 1 is
never a valid outcome), and Lottie JSON can't be parameterized at Flutter
runtime, this script bakes five full composition variants -- only the
bloom/final segments differ between them; `idle_to_broken`, `broken_loop`,
and `searching_star_loop` are pixel-identical across all five (same
hand-authored layout + per-fragment RNG seeds regardless of star count).

Each composition is a single timeline split into five named marker segments
that `lib/widgets/lottie_bolt_icon.dart` plays back by name via
`LottieComposition.getMarker`:

- "idle_to_broken": the bolt shatters into 16 fragments, played once. The
  16 land/settle at hand-art-directed (FRAGMENT_DESIGN), *asymmetric*
  positions and *varied* sizes -- some close to the bolt's original spot,
  some flung further, a few deliberately bigger "hero" shards -- so it
  reads as a designed burst/debris composition rather than a mechanical,
  evenly-spaced ring.
- "broken_loop": a seamless loop of the 16 fragments gently wiggling in
  place -- held for as long as call #1 (translate) is in flight.
- "searching_star_loop": a seamless loop where a single small star wanders
  along a closed Lissajous curve (non-linear, organic, tiles perfectly
  since sin() is exactly periodic at integer frequencies) -- held for as
  long as call #2 ("additional info") is in flight. Entering this segment,
  10 of the 16 fragments (the non-survivors) hard-cut fade away; the other
  6 (SURVIVOR_INDICES, chosen for a balanced spread of angle + size) stay
  on screen with a very subtle idle twinkle while the star wanders among
  them.
- "broken_to_stars": of the 6 surviving fragments, `star_count` of them
  (0..5, chosen for a balanced spread) shrink away while growing/fading
  into a fully-formed star (a bloom, not a disappear/reveal) at a
  hand-authored final position from STAR_LAYOUT -- one "hero" star at full
  size plus a graduated hierarchy of smaller, distinctly-sized companions,
  scattered asymmetrically but kept horizontally tight/compact; the rest
  give a brief "poof" flourish (a quick pop before fading) and dissolve to
  nothing -- including all 6 when star_count is 0, leaving a genuinely
  empty icon rather than looking like a rendering glitch. Played once.
- "stars_idle_loop": a seamless twinkle loop on the `star_count` settled
  stars (or nothing at all, for the 0-star variant). This is the permanent
  "ready" resting look.

Usage:
    pip install lottie
    python3 tool/generate_bolt_shatter_lottie.py
"""
import json
import math
import os
import random

from lottie import objects, NVector
from lottie.objects import easing
from lottie.objects.helpers import Marker
from lottie.utils.color import Color

# --- Named segments (frame ranges) ----------------------------------------
# NOTE: the *names* below are what lib/widgets/lottie_bolt_icon.dart looks up
# at runtime via LottieComposition.getMarker(...).
MARKER_IDLE_TO_BROKEN = "idle_to_broken"
MARKER_BROKEN_LOOP = "broken_loop"
MARKER_SEARCHING_STAR_LOOP = "searching_star_loop"
MARKER_BROKEN_TO_STARS = "broken_to_stars"
MARKER_STARS_IDLE_LOOP = "stars_idle_loop"

WIDTH = 200
HEIGHT = 200
CENTER = NVector(WIDTH / 2, HEIGHT / 2)
FRAMERATE = 60

IDLE_TO_BROKEN = (0, 24)          # 0.40s: bolt -> 16 fragments
BROKEN_LOOP = (24, 54)            # 0.50s: seamless wiggle loop (call #1 wait)
SEARCHING_STAR_LOOP = (54, 114)   # 1.00s: seamless Lissajous wander (call #2 wait)
BROKEN_TO_STARS = (114, 168)      # 0.90s: 6 survivors bloom into stars / dissolve
STARS_IDLE_LOOP = (168, 228)      # 1.00s: seamless twinkle loop (final "ready")
TOTAL_FRAMES = STARS_IDLE_LOOP[1]

NUM_FRAGMENTS = 16
STAR_INNER_RATIO = 0.42
SEARCH_STAR_OUTER_RADIUS = 16
SHARD_BASE_SIZE = 7.0

# Hand-art-directed (angle_deg, radius, size_scale) per fragment index --
# deliberately irregular angular spacing, mixed radii, and mixed sizes so
# the shatter reads as a designed burst/debris composition rather than a
# mechanical, evenly-spaced ring. A couple of "hero" pieces fly out further
# and bigger; several sit close and small; there are genuine open gaps
# (e.g. ~96-150 deg, ~178-205 deg) instead of uniform 360-degree coverage.
FRAGMENT_DESIGN = [
    (8, 24, 0.75),    # 0  (survivor)
    (22, 44, 1.15),   # 1
    (31, 19, 0.60),   # 2
    (58, 64, 1.45),   # 3  hero piece (survivor)
    (95, 33, 0.90),   # 4  (survivor)
    (150, 52, 1.20),  # 5
    (163, 27, 0.70),  # 6
    (178, 45, 1.00),  # 7  (survivor)
    (205, 20, 0.65),  # 8
    (230, 60, 1.35),  # 9  hero piece
    (243, 38, 0.85),  # 10 (survivor)
    (255, 24, 0.70),  # 11
    (295, 50, 1.10),  # 12 (survivor)
    (308, 30, 0.80),  # 13
    (318, 42, 0.95),  # 14
    (340, 22, 0.60),  # 15
]
assert len(FRAGMENT_DESIGN) == NUM_FRAGMENTS

# 6 of the 16 that survive into searching_star_loop and beyond, chosen to
# stay visually balanced: spread across the full circle (angular gaps of
# roughly 40-80 degrees, no big lopsided cluster) while also mixing
# small/medium/"hero"-sized pieces rather than surviving-by-size bias.
SURVIVOR_INDICES = [0, 3, 4, 7, 10, 12]
assert len(SURVIVOR_INDICES) == 6

# Hand-art-directed FINAL resting layout for the settled stars, keyed by
# star_count. Each entry is (dx, dy, size_ratio) relative to CENTER, in
# canvas units (canvas is 200x200). Independent of the 16-piece shatter
# layout on purpose -- these are absolute final targets the bloom animates
# *toward*, not derived from whichever survivor happens to bloom, so the
# resting composition itself can be deliberately designed rather than an
# accident of which shard's original angle it inherits.
#
# Design goals per count: exactly one "hero" star at size_ratio 1.0 (the
# full/primary size), the rest strictly smaller and each a distinct size
# from one another (a graduated hierarchy, not matching pairs); positions
# scattered asymmetrically but kept horizontally tight (a compact,
# vertically-taller-than-wide cluster) so the constellation doesn't
# visually compete with the text field it sits over. The first tuple in
# each list is always the hero.
STAR_LAYOUT = {
    2: [
        (-11, -23, 1.00),  # hero, upper-left of center
        (15, 19, 0.55),    # smaller companion, lower-right -- a tight duo,
    ],                     # not two dots pinned to opposite edges
    3: [
        (3, -27, 1.00),    # hero, near the top
        (-21, 9, 0.62),    # mid-size companion, left
        (15, 25, 0.46),    # smallest companion, lower-right
    ],
    4: [
        (-7, -29, 1.00),   # hero, top
        (19, -5, 0.62),    # companion, right/upper-mid
        (-19, 15, 0.52),   # companion, left/lower-mid
        (9, 31, 0.44),     # smallest companion, bottom
    ],
    5: [
        (1, -31, 1.00),    # hero, top
        (-23, -7, 0.64),   # companion, upper-left
        (21, 5, 0.55),     # companion, right-mid
        (-14, 23, 0.48),   # companion, lower-left
        (11, 35, 0.42),    # smallest companion, bottom
    ],
}
# The single full/primary star size that size_ratio 1.0 maps to.
HERO_STAR_OUTER_RADIUS = 27

# Frames used for "hard cut" hide/show transitions. Lottie linearly
# interpolates between ANY two keyframes regardless of their time gap, so a
# near-instant cut needs two *close together* keyframes with the before/
# after values -- not just one keyframe placed far from the previous one.
CUT = 2

# Purple palette throughout -- no gold/amber. Matches the app's existing
# `Colors.purple[600]` idle bolt.
SHARD_COLOR = Color(0x8E / 255, 0x24 / 255, 0xAA / 255)   # purple 600
FLASH_COLOR = Color(0xCE / 255, 0x93 / 255, 0xD8 / 255)   # purple 200
SEARCH_STAR_COLOR = Color(0xE0 / 255, 0x40 / 255, 0xFB / 255)  # purpleAccent 200
STAR_COLORS = [
    Color(0x8E / 255, 0x24 / 255, 0xAA / 255),  # purple 600 (matches idle bolt)
    Color(0xAB / 255, 0x47 / 255, 0xBC / 255),  # purple 400
    Color(0xBA / 255, 0x68 / 255, 0xC8 / 255),  # purple 300
    Color(0xCE / 255, 0x93 / 255, 0xD8 / 255),  # purple 200 (light sparkle)
]


def ease_out():
    return easing.EaseOut()


def ease_in():
    return easing.EaseIn()


def ease_in_out():
    return easing.Bezier(NVector(0.42, 0), NVector(0.58, 1))


def add_marker(anim: objects.Animation, name: str, frame_range) -> None:
    marker = Marker()
    marker.comment = name
    marker.time = frame_range[0]
    marker.duration = frame_range[1] - frame_range[0]
    anim.markers.append(marker)


def bloom_indices(star_count: int) -> set:
    """Evenly spaced subset of the 6 SURVIVOR_INDICES that bloom into
    stars; the rest of the survivors dissolve to dust. star_count may be 0
    (nothing blooms -- a genuinely empty result) up to 6 (though the app
    only ever requests 0, 2, 3, 4, or 5)."""
    n = len(SURVIVOR_INDICES)
    chosen_slots = {round(i * n / star_count) % n for i in range(star_count)}
    return {SURVIVOR_INDICES[slot] for slot in chosen_slots}


def build_flash_layer(anim: objects.Animation) -> None:
    """Quick soft radial flash at the moment of impact (t=0)."""
    layer = objects.ShapeLayer()
    layer.name = "Impact Flash"
    layer.in_point = 0
    layer.out_point = TOTAL_FRAMES
    anim.add_layer(layer)

    group = objects.Group()
    group.name = "Flash Shape"
    layer.add_shape(group)

    ellipse = objects.Ellipse()
    ellipse.position.value = NVector(0, 0)
    ellipse.size.value = NVector(46, 46)
    group.add_shape(ellipse)

    fill = objects.Fill(FLASH_COLOR)
    fill.opacity.value = 55
    group.add_shape(fill)

    t = layer.transform
    t.position.value = CENTER.clone()
    t.scale.add_keyframe(0, NVector(30, 30))
    t.scale.add_keyframe(16, NVector(170, 170), ease_out())
    t.opacity.add_keyframe(0, 70)
    t.opacity.add_keyframe(16, 0, ease_out())


def _add_search_twinkle(scale_prop, opacity_prop, visible_scale) -> None:
    """A very subtle idle breathing motion for surviving shards while the
    search star wanders -- must return to the exact search0 values by
    search1 so the repeat wraps seamlessly."""
    search0, search1 = SEARCHING_STAR_LOOP
    mid = (search0 + search1) // 2
    dim_scale = visible_scale * 0.93
    scale_prop.add_keyframe(search0, visible_scale.clone())
    scale_prop.add_keyframe(mid, dim_scale, ease_in_out())
    scale_prop.add_keyframe(search1, visible_scale.clone(), ease_in_out())
    opacity_prop.add_keyframe(search0, 100)
    opacity_prop.add_keyframe(mid, 90, ease_in_out())
    opacity_prop.add_keyframe(search1, 100, ease_in_out())


def build_fragment_layer(
    index: int,
    anim: objects.Animation,
    blooms: bool,
    star_target: tuple | None = None,
) -> None:
    """One of the 16 bolt fragments.

    Phase 1 motion (position/rotation/wiggle/size) is seeded purely by
    `index` and the hand-authored FRAGMENT_DESIGN table, so it is
    pixel-identical across all star-count variants. Only the fate from
    `searching_star_loop` onward depends on whether `index` is a survivor
    (SURVIVOR_INDICES) and, if so, whether it `blooms` -- the only things
    that differ between variants. `star_target` (required when `blooms` is
    true) is this fragment's assigned `(dx, dy, size_ratio)` slot from
    STAR_LAYOUT -- the final resting position/size is deliberately
    hand-authored per star_count rather than derived from this fragment's
    own shatter position, so the resting composition can be designed as a
    whole (see STAR_LAYOUT's docstring above).
    """
    rng = random.Random(3000 + index)
    is_survivor = index in SURVIVOR_INDICES

    angle_deg, radius, size_scale = FRAGMENT_DESIGN[index]
    angle = math.radians(angle_deg)
    dir_vec = NVector(math.cos(angle), math.sin(angle))

    broken_pos = CENTER + dir_vec * radius
    if blooms:
        dx, dy, size_ratio = star_target
        star_pos = CENTER + NVector(dx, dy)
    wiggle_pos = broken_pos + NVector(rng.uniform(-4, 4), rng.uniform(-4, 4))

    broken_rot = rng.uniform(-25, 25)
    wiggle_rot = broken_rot + rng.uniform(-10, 10)
    star_rot = broken_rot + rng.uniform(110, 200) * rng.choice([-1, 1])
    twinkle_rot = star_rot + rng.uniform(-6, 6)

    layer = objects.ShapeLayer()
    role = "star" if blooms else ("dust" if is_survivor else "gone")
    layer.name = f"Fragment {index + 1} ({role})"
    layer.in_point = 0
    layer.out_point = TOTAL_FRAMES
    anim.add_layer(layer)

    i0, i1 = IDLE_TO_BROKEN
    b0, b1 = BROKEN_LOOP
    search0, search1 = SEARCHING_STAR_LOOP
    s0, s1 = BROKEN_TO_STARS

    # --- shared motion: position + rotation -------------------------------
    t = layer.transform
    t.position.add_keyframe(i0, CENTER.clone())
    t.position.add_keyframe(i1, broken_pos.clone(), ease_out())
    t.position.add_keyframe((i1 + b1) // 2, wiggle_pos.clone(), ease_in_out())
    t.position.add_keyframe(b1, broken_pos.clone(), ease_in_out())  # == i1 value: seamless loop
    if is_survivor and blooms:
        t.position.add_keyframe(s1, star_pos.clone(), ease_in_out())
    # (non-survivors and dissolving survivors: position holds at broken_pos
    # forever -- they never move again, just fade out where they are)

    t.rotation.add_keyframe(i0, 0)
    t.rotation.add_keyframe(i1, broken_rot, ease_out())
    t.rotation.add_keyframe((i1 + b1) // 2, wiggle_rot, ease_in_out())
    t.rotation.add_keyframe(b1, broken_rot, ease_in_out())  # == i1 value: seamless loop
    if is_survivor and blooms:
        t.rotation.add_keyframe(s1, star_rot, ease_in_out())

    # --- shard shape: size + elongation vary per fragment for a hand-cut,
    # not-all-identical debris look. ---------------------------------------
    shard_group = objects.Group()
    shard_group.name = "Shard"
    layer.add_shape(shard_group)

    shard = objects.Star()
    shard.star_type = objects.StarType.Polygon
    shard.points.value = 4
    shard.position.value = NVector(0, 0)
    shard.rotation.value = 0
    shard.outer_radius.value = SHARD_BASE_SIZE
    shard.outer_roundness.value = 8
    shard_group.add_shape(shard)
    shard_group.add_shape(objects.Fill(SHARD_COLOR))

    elong_w = rng.uniform(62, 84)
    elong_h = rng.uniform(122, 165)
    visible_scale = NVector(elong_w * size_scale, elong_h * size_scale)

    shard_scale = shard_group.transform.scale
    shard_opacity = shard_group.transform.opacity
    shard_scale.add_keyframe(i0, visible_scale.clone())
    shard_opacity.add_keyframe(i0, 100)

    if not is_survivor:
        # Visible through phase 1, hard-cut hidden the instant the search
        # phase begins, and never seen again.
        shard_scale.add_keyframe(search0, visible_scale.clone())
        shard_scale.add_keyframe(search0 + CUT, NVector(0, 0))
        shard_opacity.add_keyframe(search0, 100)
        shard_opacity.add_keyframe(search0 + CUT, 0)
        return

    # Survivors stay visible (with a subtle twinkle) all the way through
    # the search phase and into the start of the bloom.
    _add_search_twinkle(shard_scale, shard_opacity, visible_scale)

    bloom_fade_end = s0 + int((s1 - s0) * 0.7)
    if blooms:
        shard_scale.add_keyframe(bloom_fade_end, NVector(0, 0), ease_in())
        shard_opacity.add_keyframe(bloom_fade_end, 0, ease_in())
    else:
        # Dissolving survivor: a quick "poof" pop just before vanishing,
        # rather than a flat shrink, so it reads as a deliberate sparkle/
        # dissolve rather than a glitch (this is what makes the 0-star
        # outcome -- where *all* 6 survivors take this path -- still feel
        # intentional instead of broken).
        poof_frame = s0 + int((s1 - s0) * 0.45)
        poof_scale = visible_scale * 1.3
        shard_scale.add_keyframe(poof_frame, poof_scale, ease_out())
        shard_scale.add_keyframe(bloom_fade_end, NVector(0, 0), ease_in())
        shard_opacity.add_keyframe(poof_frame, 100)
        shard_opacity.add_keyframe(bloom_fade_end, 0, ease_in())

    if not blooms:
        return  # dissolving survivor: nothing more to add.

    # --- star sub-shape: hidden until the bloom, then grows + twinkles ----
    star_group = objects.Group()
    star_group.name = "Star"
    layer.insert_shape(0, star_group)  # renders on top of the shard

    star = objects.Star()
    star.star_type = objects.StarType.Star
    star.points.value = 5
    star.position.value = NVector(0, 0)
    star.rotation.value = rng.uniform(0, 72)
    # size_ratio comes from STAR_LAYOUT: exactly 1.0 for the one "hero" star
    # per composition, strictly smaller (and distinct) for every companion,
    # plus a touch of per-fragment jitter so same-ratio stars across
    # different star_count variants don't look like stamped copies.
    outer_r = HERO_STAR_OUTER_RADIUS * size_ratio * rng.uniform(0.95, 1.05)
    star.outer_radius.value = outer_r
    star.inner_radius.value = outer_r * STAR_INNER_RATIO
    star.outer_roundness.value = 0
    star.inner_roundness.value = 0
    star_group.add_shape(star)
    star_group.add_shape(objects.Fill(rng.choice(STAR_COLORS)))

    star_scale = star_group.transform.scale
    star_opacity = star_group.transform.opacity
    bloom_grow_start = s0 + int((s1 - s0) * 0.25)
    pop_frame = s1 - int((s1 - s0) * 0.12)
    star_scale.add_keyframe(bloom_grow_start, NVector(0, 0))
    star_scale.add_keyframe(pop_frame, NVector(118, 118), ease_out())
    star_scale.add_keyframe(s1, NVector(100, 100), ease_out())
    star_opacity.add_keyframe(bloom_grow_start, 0)
    star_opacity.add_keyframe(pop_frame, 100, ease_out())

    # twinkle loop -- must return to the exact s1 values by the end of the
    # loop range so the repeat wraps seamlessly.
    li0, li1 = STARS_IDLE_LOOP
    mid = (li0 + li1) // 2
    star_scale.add_keyframe(li0, NVector(100, 100))
    star_scale.add_keyframe(mid, NVector(112, 112), ease_in_out())
    star_scale.add_keyframe(li1, NVector(100, 100), ease_in_out())
    star_opacity.add_keyframe(li0, 100)
    star_opacity.add_keyframe(mid, 86, ease_in_out())
    star_opacity.add_keyframe(li1, 100, ease_in_out())

    t.rotation.add_keyframe(li0, star_rot)
    t.rotation.add_keyframe(mid, twinkle_rot, ease_in_out())
    t.rotation.add_keyframe(li1, star_rot, ease_in_out())


def build_search_star_layer(anim: objects.Animation) -> None:
    """A single small star that wanders along a closed Lissajous curve
    (frequency ratio 3:2, 90-degree phase) during `searching_star_loop`.
    Sampled densely (every 2 frames) with linear segments; sin() is exactly
    periodic at integer frequencies, so the first and last samples are
    numerically identical -- the loop tiles with zero seam."""
    layer = objects.ShapeLayer()
    layer.name = "Searching Star"
    layer.in_point = 0
    layer.out_point = TOTAL_FRAMES
    anim.add_layer(layer)

    group = objects.Group()
    group.name = "Search Star Shape"
    layer.add_shape(group)

    star = objects.Star()
    star.star_type = objects.StarType.Star
    star.points.value = 5
    star.position.value = NVector(0, 0)
    star.rotation.value = 0
    star.outer_radius.value = SEARCH_STAR_OUTER_RADIUS
    star.inner_radius.value = SEARCH_STAR_OUTER_RADIUS * STAR_INNER_RATIO
    star.outer_roundness.value = 0
    star.inner_roundness.value = 0
    group.add_shape(star)
    group.add_shape(objects.Fill(SEARCH_STAR_COLOR))

    t = layer.transform
    i0, i1 = IDLE_TO_BROKEN
    search0, search1 = SEARCHING_STAR_LOOP
    s0, s1 = BROKEN_TO_STARS

    # Lissajous trajectory, amplitude tuned to stay within the icon's
    # bounding box.
    freq_x, freq_y, phase_x = 3, 2, math.pi / 2
    amp_x, amp_y = 46, 34
    loop_frames = search1 - search0
    step = 2
    n_samples = loop_frames // step + 1  # includes both endpoints (identical)

    positions = []
    for k in range(n_samples):
        frame = search0 + k * step
        u = (frame - search0) / loop_frames  # 0..1
        x = CENTER.x + amp_x * math.sin(2 * math.pi * freq_x * u + phase_x)
        y = CENTER.y + amp_y * math.sin(2 * math.pi * freq_y * u)
        positions.append((frame, NVector(x, y)))

    # Hidden (parked at center) until a hard cut right at search0, wanders
    # for the loop, then hard-cut hidden again right after search1. Since
    # search1 == s0 (contiguous markers), the "hide after" cut lands just
    # inside broken_to_stars, which is harmless (never rendered in practice
    # -- the widget jumps straight to broken_to_stars's own frame via a
    # crossfade dip rather than animating continuously through this point).
    t.position.add_keyframe(i0, CENTER.clone())
    t.position.add_keyframe(search0 - CUT, CENTER.clone())
    for frame, pos in positions:
        t.position.add_keyframe(frame, pos.clone())

    # One full continuous spin per loop cycle -- 360 degrees tiles seamlessly.
    t.rotation.add_keyframe(search0, 0)
    t.rotation.add_keyframe(search1, 360)

    scale = group.transform.scale
    opacity = group.transform.opacity
    scale.add_keyframe(i0, NVector(0, 0))
    scale.add_keyframe(search0 - CUT, NVector(0, 0))
    scale.add_keyframe(search0, NVector(100, 100))
    # a couple of gentle pulses while wandering, seamless (2 full cycles)
    scale.add_keyframe(search0 + loop_frames // 4, NVector(118, 118), ease_in_out())
    scale.add_keyframe(search0 + loop_frames // 2, NVector(100, 100), ease_in_out())
    scale.add_keyframe(search0 + 3 * loop_frames // 4, NVector(118, 118), ease_in_out())
    scale.add_keyframe(search1, NVector(100, 100), ease_in_out())
    scale.add_keyframe(search1 + CUT, NVector(0, 0))

    opacity.add_keyframe(i0, 0)
    opacity.add_keyframe(search0 - CUT, 0)
    opacity.add_keyframe(search0, 100)
    opacity.add_keyframe(search1, 100)
    opacity.add_keyframe(search1 + CUT, 0)


def build(star_count: int) -> objects.Animation:
    anim = objects.Animation(n_frames=TOTAL_FRAMES, framerate=FRAMERATE)
    anim.width = WIDTH
    anim.height = HEIGHT
    anim.name = f"BoltShatterStars{star_count}"
    anim.in_point = 0
    anim.out_point = TOTAL_FRAMES
    anim.markers = []

    add_marker(anim, MARKER_IDLE_TO_BROKEN, IDLE_TO_BROKEN)
    add_marker(anim, MARKER_BROKEN_LOOP, BROKEN_LOOP)
    add_marker(anim, MARKER_SEARCHING_STAR_LOOP, SEARCHING_STAR_LOOP)
    add_marker(anim, MARKER_BROKEN_TO_STARS, BROKEN_TO_STARS)
    add_marker(anim, MARKER_STARS_IDLE_LOOP, STARS_IDLE_LOOP)

    build_flash_layer(anim)
    build_search_star_layer(anim)

    blooming = bloom_indices(star_count)
    assert len(blooming) == star_count
    assert blooming <= set(SURVIVOR_INDICES)

    # Assign each blooming fragment a slot in the hand-authored STAR_LAYOUT
    # for this star_count (sorted for a stable, deterministic assignment).
    # Which physical shard ends up as the "hero" vs. a companion varies by
    # star_count (a side effect of which survivors bloom_indices picks),
    # but the *layout itself* -- positions and the size hierarchy -- is
    # always the fully designed STAR_LAYOUT, never derived from the
    # fragment's own shatter position.
    star_targets = {}
    if star_count > 0:
        layout = STAR_LAYOUT[star_count]
        assert len(layout) == star_count
        for slot, frag_index in enumerate(sorted(blooming)):
            star_targets[frag_index] = layout[slot]

    for i in range(NUM_FRAGMENTS):
        build_fragment_layer(
            i, anim, blooms=i in blooming, star_target=star_targets.get(i)
        )

    return anim


def validate(out_path: str, star_count: int) -> None:
    with open(out_path) as fh:
        data = json.load(fh)

    assert data["w"] == WIDTH and data["h"] == HEIGHT
    assert data["fr"] == FRAMERATE
    assert data["op"] == TOTAL_FRAMES
    assert len(data["layers"]) == NUM_FRAGMENTS + 2  # flash + search star + 16
    marker_names = {m["cm"] for m in data["markers"]}
    assert marker_names == {
        MARKER_IDLE_TO_BROKEN,
        MARKER_BROKEN_LOOP,
        MARKER_SEARCHING_STAR_LOOP,
        MARKER_BROKEN_TO_STARS,
        MARKER_STARS_IDLE_LOOP,
    }, marker_names
    for layer in data["layers"]:
        assert layer["ty"] == 4, "expected shape layer"

    star_layers = [layer for layer in data["layers"] if layer["nm"].endswith("(star)")]
    dust_layers = [layer for layer in data["layers"] if layer["nm"].endswith("(dust)")]
    gone_layers = [layer for layer in data["layers"] if layer["nm"].endswith("(gone)")]
    assert len(star_layers) == star_count, (out_path, len(star_layers), star_count)
    assert len(dust_layers) == 6 - star_count, (out_path, len(dust_layers), star_count)
    assert len(gone_layers) == NUM_FRAGMENTS - 6

    reloaded = objects.Animation.load(data)
    assert len(reloaded.layers) == NUM_FRAGMENTS + 2
    assert len(reloaded.markers) == 5


def main():
    out_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "animations"))
    os.makedirs(out_dir, exist_ok=True)

    for star_count in (0, 2, 3, 4, 5):
        anim = build(star_count)
        out_path = os.path.join(out_dir, f"bolt_shatter_stars_{star_count}.json")
        with open(out_path, "w") as fh:
            json.dump(anim.to_dict(), fh, indent=2)
        validate(out_path, star_count)
        print(f"Wrote + validated {out_path}")

    print("All variants generated and sanity-checked OK.")


if __name__ == "__main__":
    main()
