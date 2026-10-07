<p align="center">
  <img src="assets/fly.png" width="340" alt="SiliconFly — a 3D fruit fly">
</p>

<h1 align="center">FlyGift 🎁🪰</h1>

<p align="center">
A mysterious macOS gift that opens into a 60-second fly-swatting challenge,
powered by a live 1 kHz simulation of the <b>whole</b>
<a href="https://codex.flywire.ai">FlyWire</a> connectome — 139,255 neurons on
the Apple GPU.
</p>

## The gift

FlyGift begins as a deliberately suspicious, fully rendered 3D present. The
opening shot uses ETechStudios' external CC0 gift-box mesh, with FlyGift's own
physically based paper/ribbon materials, lighting, slow turn and unwrapping
animation. Open it, then click the red Chinese-style plastic fly swatter itself
to pick it up—there is no separate pickup button. A morphology-informed fruit
fly emerges after a random delay.
Its approach response enters the real LC4/LPLC2 looming circuit; it takes off
when the simulated DNp01 / Giant Fiber actually spikes. You have 60 seconds to
catch it while it is grounded.

- The first 50 seconds have no HUD; a countdown appears for the final 10.
- The fly can cross between real desktop windows, land on their edges, hide
  beneath them, and rush toward the camera once during the challenge.
- Flight is continuously integrated rather than played as a fixed point-to-point
  clip: DNa steering, looming activity, escape drive and wing effort keep bending
  speed, heading, altitude and landing timing while the fly is already airborne.
- The visible body uses a dorsal *Drosophila* reference with red compound eyes,
  a tan thorax, segmented abdomen, translucent veined wings, and six fine legs.
- The rendered 72×54 plastic swatter head—not just the cursor point—is used for
  hit testing. Its position, angular size, approach velocity and swing pulse also
  become the looming/air-puff stimulus presented to the fly.
- Collision is swept across the full 220 ms swing rather than sampled only on
  mouse-down. A 140 ms takeoff grace window resolves visible last-moment contact,
  and every landing gets a brief 480 ms GF refractory opportunity.
- Shake the cursor back and forth to arm the power-up: the whole swatter—graphic
  and hit shape together—grows to 1.7× for 4 seconds. The enlarged head subtends
  a bigger looming stimulus, so it reaches further but spooks the fly sooner.
- A successful hit leaves an original macro-style insect residue for one beat,
  then a cyan scan ring dissolves it into blue-and-gold luminous data particles:
  the physical prank becomes the digital-life reveal.
- Double-press `Esc`, use the menu-bar gift icon, or press `Cmd-Q` to quit.
- The app is offline, has no analytics, and requests no Screen Recording or
  Accessibility permission.
- The reveal explains which parts are measured connectome data and which parts
  remain computational modeling.

The share page is designed for GitHub Pages. With `?from=NAME`, it presents a
personalized but spoiler-free download page. Without the parameter it creates a
shareable gift link.

The packaged gift mesh is the
[Gift Box 3D model by ETechStudios](https://etechstudios.itch.io/giftmodel),
released under CC0. Its source and license notice are preserved in
`assets/gift-box-cc0/README.md` and inside the App bundle. The splat image is an
original generated asset, not a copied web photograph.

## Build FlyGift

Requirements: Apple Silicon, macOS 15+, and Xcode Command Line Tools.

```sh
./build.sh
open build/FlyGift.app
```

The build also produces `build/FlyGift-macOS-arm64.zip` and
`build/SHA256SUMS.txt`. Run the headless game-flow checks with:

```sh
./FlyGift --gametest
```

### macOS download and first launch

Unzip the download, move `FlyGift.app` to Applications and double-click it.
Preview builds have a complete ad-hoc bundle signature, verified before packaging,
but are not Developer ID signed or Apple notarized. If macOS blocks launch because
it cannot verify the developer, review the source and use the app-specific
**System Settings → Privacy & Security → Open Anyway** option if offered.
Control-click is not a reliable first-launch instruction on recent macOS versions.

An **“app is damaged”** warning is a different failure. Download a fresh copy and
compare its ZIP checksum with `SHA256SUMS.txt`. If it persists, report the exact
message and macOS version rather than disabling Gatekeeper. A valid local signature
and SHA-256 checksum establish integrity, not Apple trust or a malware review.

For production distribution, install a Developer ID Application certificate and
store notarization credentials in Keychain with `xcrun notarytool store-credentials`.
Build with these environment variables (names only; no secrets belong in source):

```sh
FLYGIFT_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
FLYGIFT_NOTARY_PROFILE='FlyGift-notary' ./build.sh
```

The build signs with hardened runtime, submits to Apple, staples the ticket,
validates it and checks Gatekeeper before creating the final ZIP and checksum.
Without those variables, it creates the explicitly unnotarized preview.

<p align="center"><sub>
Built on <a href="https://github.com/DenisSergeevitch/desktop-fly">DesktopFly</a> by Denis Shiryaev,
which contributed the procedural fly body, the behaviour system and the desktop overlay.
FlyGift is based on <a href="https://github.com/dawsonamf/siliconfly">SiliconFly</a>,
which replaced DesktopFly's 668-neuron CPU circuit with the whole connectome on the GPU.
</sub></p>

<p align="center">
  <img src="assets/brain.png" width="560" alt="Live brain window: real FlyWire neuron positions, spikes flashing">
</p>

<p align="center"><sub>
The fly's brain window: real neuron soma positions from FlyWire v783, with live
spikes flashing at real neuron locations. The two glowing yellow markers are the
Giant Fibers — the escape command neurons. Click any region to stimulate it.
(This shot predates the whole-brain port; the window now draws all 139,255 somas.)
</sub></p>

## What's real

- **The whole connectome runs.** 139,255 neurons, 15,091,983 signed edges and
  54,492,922 synapses from FlyWire FAFB v783 step as one
  leaky-integrate-and-fire (LIF) network at **1 kHz** inside a Metal compute
  shader. Nothing is subsampled — ~95 MB of connectome ships with the repo and
  every neuron of it is simulated, every millisecond.
- **The neurons that drive the body are named cells**; the other 138,877 are the
  network they sit in:
  - **LC4 (104) + LPLC2 (210)** looming-detector visual neurons
  - **DNp01 / Giant Fiber (GF) (2)** — the escape command neuron
  - **DNa01 (2) + DNa02 (2)** steering · **DNp09 (2)** forward walking
  - **DNg11 (6)** grooming · **MDN (4)** backward walking ("moonwalker")
  - **DNp02/DNp04/DNp11 (6)** escape-maneuver (wing) neurons
  - **24 ascending** (leg proprioception) and **16 sensory** (wind/tap) neurons,
    the two places the body writes back into the brain
- **The command neurons have no life of their own.** Re-run the same sim with
  the synaptic weights zeroed and DNa01/02, MDN and DNg11 sit at **0.00 Hz**,
  the wing DNs at 0.04 Hz; wired up they run at 0.5–50 Hz. Every spike they emit
  is the connectome's, not a baseline's (`--brainstats`).
- **Escape is not scripted.** Your cursor's approach becomes looming input to the
  real LC4/LPLC2 cells. The two Giant Fibers take 9,474 synapses of input
  between them, excitatory *and* 4 ms-delayed feedforward inhibitory, so a slow
  approach is tolerated while an abrupt one fires them in **3 ms** — the fly
  takes off only when DNp01 actually spikes.

The body itself is procedural (FlyWire is a brain connectome — no body geometry
exists), with a tripod gait, visible wing-beat, altitude-scaled flight, grooming
and sleep postures.

## How it works

```
data/*.bin  ──►  MetalSim ──► two Metal kernels per simulated ms ──► population
(CSR graph)      (GPU LIF)     lif_update  +  lif_propagate          rates (EMA)
                                                                        │
   fly body ◄── FlyModel ◄── BrainSignals ◄── SignalBuilder ◄───────────┘
```

Per simulated millisecond, `LIF.metal` runs twice:

1. **`lif_update`** — one thread per neuron: apply the excitation the previous
   step's spikes delivered, leak toward a per-super-class resting drive, add a
   noise kick, add sensory drive (loom / gait / air puff / click stimulation),
   apply the inhibition scheduled 4 ms ago, then threshold and reset.
2. **`lif_propagate`** — one 32-lane SIMD group per *spiking* neuron, scattering
   only that neuron's CSR row. At rest ~250 of 139,255 neurons spike per ms, so
   the step touches a few tens of thousands of edges instead of all 15 million.

Synaptic accumulation is Int32 fixed point (Q16) with integer atomics, so the
sum is independent of thread order and the whole sim is reproducible from its
seed. Noise is a PCG hash of `(seed, step, neuron)` rather than a sequential RNG,
for the same reason — which is what makes an independent CPU reference able to
reproduce the GPU bit for bit (`--gpucheck`).

Measured on an M4 Pro (`--simtest`, `--brainstats 4`, shipped seed):

```
metal-sim: Apple M4 Pro N=139255 E=15091983 load 40 ms compile 1 ms
population: 1.75 Hz/neuron | 244 spikes/step | 78 µs/step (16-step batches)
bench 16-step batches: 69 µs/step, 249 spikes/step
bench  1-step batches: 192 µs/step, 240 spikes/step
PASS realtime: 16-step batches 69 µs/step (budget 1000)
```

The render loop steps the sim in 8–50 ms batches, so the 16-step number is the
one that matters: **69–78 µs of wall time per simulated millisecond, ~13–14×
faster than real time**. Startup is ~40 ms to parse, validate and upload the
connectome plus ~1 ms to compile the shader (`LIF.metal` is compiled at runtime;
a cold shader cache costs ~85 ms once). Peak resident memory is ~240 MB.

The brain window draws all 139,255 somas as a single point cloud coloured by
super-class, the 378 role-tagged neurons as an overlay, and flashes spikes
sampled off the GPU each step.

## Installation

Requirements: an **Apple Silicon Mac**, **macOS 15+** (the shader is compiled
with `MTLCompileOptions.mathMode`), and the Xcode Command Line Tools. Built and
tested on macOS 26.6.1 / M4 Pro / Swift 6.2.1. `build.sh` is bare `swiftc` — no
Xcode project, and no Metal toolchain, since `LIF.metal` is compiled at runtime.
Python is needed only to regenerate `data/`.

No permissions or entitlements are required — everything it senses (cursor,
window frames, clicks-as-taps, thermal state) is permission-free.

```sh
git clone https://github.com/ThomasLin070217/FlyGift.git
cd FlyGift
./build.sh
open build/FlyGift.app
```

A gift item appears in the menu bar. The fly uses a transparent overlay, while
a small geometry-matched hit window accepts clicks only over its rendered body;
the rest of the desktop stays click-through.

## Controls (menu bar 🪰)

| item | effect |
|---|---|
| Mute | toggle all procedural audio |
| End Gift | cleanly restore the cursor, stop audio, and quit |
| Double `Esc` | immediately cancel from anywhere in the challenge |

The original connectome diagnostics remain available to developers through the
command-line checks (`--simtest`, `--gpucheck`, `--behaviortest`, and
`--brainshot`). They are not shown during the spoiler-free gift flow.

## How real neurons drive the body

| body behavior | driven by | population | its wired input |
|---|---|---|---|
| escape takeoff | DNp01 spike | 2 | 9,474 syn / 962 edges |
| walk vs. rest, walking speed | DNp09 rate | 2 | 10,287 syn / 1,362 edges |
| steering | DNa01+DNa02 left−right rate difference | 2 + 2 | 12,495 + 25,427 syn |
| grooming | DNg11 rate | 6 | 3,535 syn / 589 edges |
| backward scoot | MDN rate above 60 Hz | 4 | 10,519 syn / 1,772 edges |
| wing-beat effort, threat wing-raise | DNp02/04/11 rate | 6 | 19,253 syn / 3,225 edges |
| nervous darting | LC4/LPLC2 population rate | 104 + 210 | 1,885 syn / 293 edges onto the GF |
| spontaneous takeoff | whole-population rate | 139,255 | — |

Those in-degrees are the point of the port: in the old 668-neuron circuit DNg11
received **6** synapses and was effectively noise-driven; it now receives 3,535.
In threshold units (1.0 = one presynaptic volley fires the cell from rest) the
`--brainstats` in-weight audit reads `dnaL +17.46/−11.47`, `fwd +9.87/−6.57`,
`gf +2.30/−0.91` excitatory/inhibitory — every population is a live tug-of-war,
not a feed-forward wire.

The loop also closes body→brain: the gait rhythm feeds 24 real ascending
(proprioceptive) neurons in phase with the legs, and fast cursor motion
stimulates 16 sensory (wind) neurons.

## Desktop ecology (all permission-free macOS senses)

- **Window terrain**: window top edges are ledges — the fly lands on them,
  walks along them, rides a window you drag, and startles when one closes
  under its feet.
- **Window looms**: a window appearing near the fly feeds the looming
  pathway; the circuit decides whether to flee your dialogs.
- **Clicks are substrate taps**; clicking next to the fly startles it through
  the wind→GF pathway. **Typing is vibration** (idle-time API — knows *when*
  keys were pressed, never which).
- **Circadian rhythm**: dawn/dusk activity peaks, midday siesta, night
  quiescence. **Sleep**: idle at night → it sleeps, breathing slowly, with
  raised arousal threshold; it grooms after waking.
- **Temperature**: flies are ectotherms — a hot Mac is a faster fly.

## Regenerating the data

`data/` ships the whole FAFB v783 connectome as compact binaries:

| file | size | contents |
|---|---|---|
| `connectome.json` | 122 kB | manifest: array layout, string tables, normalization, provenance, sha256s |
| `neurons.bin` | 4.2 MB | per-neuron `pos`/`superClass`/`side`/`nt`/`role`/`cellType`/`rootId` + CSR `rowStart` |
| `synapses.bin` | 90.6 MB | CSR `colIdx` (uint32) + signed synapse `weight` (int16) |

139,255 neurons, 15,091,983 edges, 54,492,922 synapses. Every array is
16-byte aligned, little-endian, and described by `connectome.json` — that
manifest is the loader's contract, not the file order.

To rebuild from the raw sources (~160 MB download):

```sh
mkdir -p cache/flywire783 && cd cache/flywire783
B=https://storage.googleapis.com/flywire-data/codex/data/fafb/783
curl -O "$B/classification.csv.gz" -O "$B/coordinates.csv.gz" \
     -O "$B/consolidated_cell_types.csv.gz" -O "$B/neurons.csv.gz"
curl -LO https://github.com/eonsystemspbc/fly-brain/raw/main/data/2025_Connectivity_783.parquet
cd -
/opt/anaconda3/bin/python3 etl.py cache/flywire783    # ~4 s
/opt/anaconda3/bin/python3 tools/verify_data.py data  # exits non-zero on any problem
```

The ETL needs **numpy + pyarrow**, so it must run under a real Python
(Anaconda above); macOS's stock `python3` has neither. `--min-syn N` prunes
weak pairs (default 1 = keep everything); `--out DIR` redirects the output.
`tools/verify_data.py` re-reads the binaries from the manifest alone, checks
the CSR invariants, and re-derives three edges from the parquet.

Synapse weights are signed per presynaptic neuron (Dale's law): from the Codex
`nt_type` where it exists (ACH/DA/SER/OCT excitatory, GABA/GLUT inhibitory),
and from the parquet's own `Excitatory` call for the 18,314 wired neurons Codex
leaves unlabelled — 5,700 of those turn out inhibitory. Ahead of that, 94
`nt_type`-less antennal-lobe local interneurons (`primary_type` matching
`^(lLN|il3LN|v2LN)`) are forced inhibitory, since that family is canonically
GABA/Glut and signing it excitatory pins the sim at its refractory ceiling.
Neurons that do have a Codex `nt_type` are never overridden. The `nt` byte stays
`UNKNOWN` for them, so an `UNKNOWN` neurotransmitter never implies an
excitatory weight. `connectome.json` records the rule in `signPolicy`.

## Diagnostics

```sh
./SiliconFly --simtest         # sim invariants at whole-brain scale + throughput bench (~10 s)
./SiliconFly --behaviortest    # 17 end-to-end checks: stimulate neurons -> body reacts
./SiliconFly --gpucheck        # GPU sim vs an independent CPU reference, bit for bit (~12 s)
./SiliconFly --brainstats 4    # 4 s of rest: rates by super class / role / cell type (~2 s)
./SiliconFly --snapshot f.png  # offscreen fly render
./SiliconFly --brainshot b.png # offscreen brain render
./SiliconFly --seed 0x1234     # pin the sim seed for any of the above
```

`--simtest` exits non-zero if any of these stops holding: the Giant Fiber is
**silent over 4 s of rest**, it **fires under an abrupt loom** (3 ms on the
shipped seed), the walk drive **fluctuates** instead of latching, a click
stimulation of the GF cluster **reaches the body**, the siesta (`activityScale`
0.84) leaves walk drive on **more than 3 %** of the time, the GPU's spike list
agrees with its own membrane/refractory/histogram state, and 16-step batches stay
**under the 1 ms real-time budget**. It also prints the numbers the tuning pass
watches but does not assert: loom latency (single-digit ms) and walk duty
(20–50 %).

`--gpucheck` re-derives all 15,091,983 quantized weights, replays a battery of
scenarios against a CPU reference written from the pre-port sim, and checks
spikes, refractory state, group histograms, rate EMAs and every membrane
potential each step — currently bit-identical (`0 differ`, `ref 179688 spikes,
gpu 179688 spikes`).

Diagnostic modes use the shipped seed so they are reproducible; the app itself
draws a fresh seed per launch, so two launches are not the same fly.

## What's modeled vs. measured

The connectome gives wiring, not physiology. What FlyWire measured: who connects
to whom, with how many synapses, and each neuron's predicted neurotransmitter.
Everything below is a modeling choice layered on that graph.

- **LIF dynamics**: one shared 20 ms membrane time constant, threshold 1,
  2 ms refractory period, one global weight scale (0.0032 per synapse). Real
  neurons differ in all of these.
- **Signs**: Dale's law per presynaptic neuron, from the Codex `nt_type`; a
  parquet fallback for the 18,314 wired neurons it leaves unlabelled; and an
  explicit inhibitory prior for 94 antennal-lobe local interneurons (see
  "Regenerating the data"). Modulatory synapses (DA/SER/OCT) are scaled ×0.5
  rather than modelled as neuromodulation.
- **The Giant Fiber gets three separate input gains**: its documented electrical
  coupling from LC4/LPLC2 and from the wind-sensitive afferents is boosted, and
  its ~3,800 ordinary chemical synapses per cell are scaled *down* (×0.12).
  Without that third gain a LIF with one threshold for everybody makes in-degree
  a proxy for excitability, and the giant fiber — which collects far more input
  than a median neuron — fires spontaneously. It is a model fix, not a connectome
  fix.
- **Resting drive and noise are invented.** There is no photoreceptor input, no
  sensory periphery beyond the loom, gait and wind pathways wired in by hand, and
  no neuromodulatory state,
  so each neuron gets a small per-super-class resting drive and a stochastic
  membrane kick to keep the brain alive. The whole-brain rate at rest, 1.75 Hz
  per neuron, is a consequence of those two knobs, not a measurement.
- **One delay for inhibition.** Excitation arrives on the next step; inhibition
  arrives 4 ms later. Real conduction delays vary per connection and are unknown.
- **No VNC and no body physics.** FlyWire is a brain connectome; the ventral
  nerve cord that actually drives the legs is not in it. Descending-neuron rates
  are read out as commands and the gait, flight and grooming are procedural.
- **No spike-frequency adaptation, no synaptic plasticity, no gap junctions**
  beyond the two GF boosts above.
- **The escape race is a race, and it is only half honest.** Under a *sustained*
  artificial loom the GF fires 147 times in 400 ms, which no real fly does; the
  body uses the first spike and ignores the rest. The behaviour it produces
  (fast lunge → takeoff, slow approach → tolerated) is right; the spike train
  under a held stimulus is not.

## License & citation

Code is MIT, copyright Denis Shiryaev and Dawson Metzger-Fleetwood: this repo
began as [DesktopFly](https://github.com/DenisSergeevitch/desktop-fly) and keeps
its full git history, so `git log` and `git blame` show which lines came from where.
The files in `data/` are derived from FlyWire (FAFB v783) and
are **CC BY-NC 4.0** — see [data/DATA_LICENSE.md](data/DATA_LICENSE.md).
The aggregated connectivity table comes from
[eonsystemspbc/fly-brain](https://github.com/eonsystemspbc/fly-brain)
(FlyWire `proofread_connections_783`, [Zenodo 10676866](https://doi.org/10.5281/zenodo.10676866)).
[webgpu-fly](https://github.com/abgnydn/webgpu-fly) (MIT) was read as a design
reference for running the full connectome as a LIF network on a GPU.
If you use this, cite:

- Dorkenwald, S. et al. *Neuronal wiring diagram of an adult brain.* Nature 634, 124–138 (2024). https://doi.org/10.1038/s41586-024-07558-y
- Schlegel, P. et al. *Whole-brain annotation and multi-connectome cell typing of Drosophila.* Nature 634, 139–152 (2024). https://doi.org/10.1038/s41586-024-07686-5
