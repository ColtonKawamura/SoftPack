# `Movie()`

*Up:* [`movie`](index.md)

```
pack(movie = Movie("packing.mp4"; every = 500, size = 720, fps = 30))
```

Render a frame every `every` steps into a temporary directory and encode the frames into
`path` when the run ends (design §11). `every` can also be a wall-clock period. The frame
is `size` pixels square; `fps` is the frame rate of the encoded movie.

The renderer is the one of [`render_frame!`](../../../reference/rendering.md): disks or
spheres with depth fog, wrapped at the edges of a periodic box, and a thin diameter line on
every particle when the packing has friction, so the rotation is visible in the movie.

Encoding needs `ffmpeg` on the `PATH`. Without it the run still packs and the movie is
skipped with a warning in `packing.control.warnings`; if encoding fails, the frame
directory is kept and its path is reported, so the frames are not lost.

A movie adds little to the run time: a 720-pixel frame of 256 disks takes 1.3 ms, so a
frame every 500 steps over 87,000 steps costs about a second. The frames are large (about
1.5 MB each as PPM) but they live in the temporary directory and only the encoded movie is
kept.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `path` | required | the movie file; the extension picks the container ffmpeg writes |
| `every` | required | steps (an integer) or a period between frames |
| `size` | `640` | the image width in pixels |
| `fps` | `25` | frames per second of the movie |

## Archival reference

- [pack(movie = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#packmovie--)
- [Snapshots and movie](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#snapshots-and-movie)
