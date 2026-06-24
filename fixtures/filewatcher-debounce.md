# FileWatcher debounce — implementation notes

Agents don't save files the way people do. <mkdn-comment id="edit" edge="start"/>A single logical edit often lands as <mkdn-comment id="writes" edge="start"/>three writes inside 40 ms<mkdn-comment id="writes" edge="end"/><mkdn-comment id="edit" edge="end"/> — and today each one triggers a full re-render. On a large document that's a visible stutter storm right when you're trying to read.

## Approach

Coalesce change events instead of reacting to each one: a leading-edge reload at 50 ms, with a <mkdn-comment id="cap" edge="start"/>200 ms max-latency cap<mkdn-comment id="cap" edge="end"/> so a steady stream still paints continuously instead of starving behind the debounce.

```swift
func handle(_ event: FileEvent) {
    debouncer.schedule(leading: .milliseconds(50),
                       maxLatency: .milliseconds(200)) { [weak self] in
        self?.reload(event.url)
    }
}
```

The debounce keys on the <mkdn-comment id="path" edge="start"/>resolved path<mkdn-comment id="path" edge="end"/>, so a save that lands through a symlink and a direct write to the target coalesce into one reload.

## Rollout

| Stage | Gate | Status |
| --- | --- | --- |
| Canary (internal) | no dropped reloads in a 2-hour harness soak | done |
| Default-on | p95 reload latency under one frame | in review |

## Open questions

- Should the breathing rate pulse <mkdn-comment id="pulse" edge="start"/>once per coalesced batch, or once per write<mkdn-comment id="pulse" edge="end"/>?
- Do we keep the 50 ms leading edge on battery, or stretch it?

<!--mkdn-comments
{
  "comments" : [
    {
      "body" : "this is the case that matters — worth calling out in the PR title.",
      "id" : "edit",
      "norm" : 1,
      "prefix" : "",
      "quote" : "a single logical edit often lands as three writes inside 40 ms",
      "suffix" : ""
    },
    {
      "body" : "measured, or estimated? if measured, link the trace.",
      "id" : "writes",
      "norm" : 1,
      "prefix" : "",
      "quote" : "three writes inside 40 ms",
      "suffix" : ""
    },
    {
      "body" : "where did 200 ms come from? feels arbitrary.",
      "id" : "cap",
      "norm" : 1,
      "prefix" : "",
      "quote" : "200 ms max-latency cap",
      "suffix" : ""
    },
    {
      "body" : "does this cover hardlinks too, or only symlinks?",
      "id" : "path",
      "norm" : 1,
      "prefix" : "",
      "quote" : "resolved path",
      "suffix" : ""
    },
    {
      "body" : "once per batch. per-write is exactly the noise we're killing.",
      "id" : "pulse",
      "norm" : 1,
      "prefix" : "",
      "quote" : "once per coalesced batch, or once per write",
      "replies" : [
        {
          "author" : "claude",
          "body" : "done — the orb pulses once per batch commit now, pushed in 8c41d2a with a soak test covering the 40 ms triple-write case.",
          "id" : "r1"
        }
      ],
      "suffix" : ""
    }
  ],
  "v" : 1
}
-->
