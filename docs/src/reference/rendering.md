# Images and movies

*Up:* [Reference](naming.md)

Every image SoftPack writes comes from the same renderer, `SoftPack.render_frame!`, which
draws the current state into a PPM file with no plotting library. A movie is a directory
of such frames encoded by ffmpeg at the end of the run; a snapshot stores positions rather
than pixels, so it can be redrawn later at any size.

## What a frame shows

- Disks in 2D and spheres seen from above in 3D, coloured by diameter: the small
  population in one colour, the large one in another.
- In 3D the far particles are drawn first, smaller and blended toward white, so the
  depth reads without lighting or transparency.
- In a periodic box a particle that crosses the frame is drawn again on the opposite
  side, so the packing looks continuous at the edges. A `Walls` system gets a frame
  instead.
- No axes, no labels, no scale bar: the frame is the box, and its width is the box side.
  `margin` widens the frame beyond the box on every side, which is how a rotated view of
  a periodic packing is drawn without cutting its corners off; with a margin the wrapped
  copies are not drawn, because the frame no longer ends at the box edge.

## The rotation marker

`render_frame!` reads `system.friction`: when the system carries friction it draws a thin
dark line through every particle's diameter, at that particle's own rotation angle, so
rotation and rolling are visible in a still as well as in a movie. The line is body-fixed:
in 2D its angle is the rotation angle, and in 3D it is the particle's $x$ diameter turned
by the rotation vector with Rodrigues' formula and then projected on the image plane. A
sphere whose diameter points at the camera shows a foreshortened line, and below a sixth
of the diameter the frame draws a small dot instead, because the line would vanish.

Pass `markers = true` or `markers = false` to `render_frame!` or to `render_packing` to
force the lines on or off; the default `nothing` follows the friction setting.

```
render_packing("packing.ppm", packing; size = 720)
SoftPack.render_packing("packing.ppm", packing, markers = false)
```

## Movies

```julia
pack(movie = Movie("packing.mp4"; every = 500, size = 720, fps = 30))
```

A `Movie` renders a frame every `every` steps (or every elapsed interval) into a
temporary directory and encodes them into `path` when the run ends. The PPM frames are
deleted afterwards unless encoding failed, in which case the directory is kept and its
path is reported in `packing.control.warnings`. Encoding needs `ffmpeg` on the `PATH`; a
run without it still packs, and the movie is skipped with a warning.

## Cost

Rendering a 720 pixel frame of 256 disks takes a few milliseconds, so a movie every 500
steps over an 87,000 step run adds about a second to the run and one frame per 500 steps.
The frames are 3 bytes per pixel before encoding; a full video of the default packing is
about 1.5 MB.
