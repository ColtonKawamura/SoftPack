# `movie`

*Up:* [Available options](../index.md)

Render a movie of the run: a frame every `every` steps, drawn straight from the positions,
encoded with ffmpeg at the end. A movie shows how the packing gets there, which a snapshot
cannot; the price is one image per frame and an ffmpeg run at the end.

Nothing is recorded by default (**SoftPack choice**).

**Default:** `nothing`

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`Movie()`](Movie.md) |  |

## Example

```julia
using SoftPack

packing = pack(
    movie = Movie(
        "packing.mp4",
        every = 1_000,
    ),
    particles_count = 256,
    seed = 1,
)
```
