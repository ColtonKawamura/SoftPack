# ---------------------------------------------------------------------------
#  Movie frames (design §11): each frame is a PPM image drawn straight from the
#  positions; ffmpeg turns the frames into the movie at the end of the run.
#  A PPM needs no library, and ffmpeg is the only external tool.
# ---------------------------------------------------------------------------

const SMALL_COLOR = (UInt8(70), UInt8(130), UInt8(180))
const LARGE_COLOR = (UInt8(235), UInt8(145), UInt8(60))
const MARKER_COLOR = (UInt8(30), UInt8(30), UInt8(30))

"""
    render_frame!(path, system, size; markers = nothing)

Draw the current state as a `size` by `size` PPM image: disks (2D) or spheres seen from
above (3D, with the far particles drawn first, smaller and fainter), coloured by diameter,
with a frame for walls. No axes, no labels.

When the system carries friction, every particle also gets a thin dark line through its
diameter, at the particle's own rotation angle, so the rotation is visible in a movie or
a still. A sphere whose diameter line points at the camera is foreshortened; when it is
shorter than a sixth of the diameter the frame draws a small dot instead, because the
line would vanish. `markers = true` or `false` forces the lines on or off; the default
`nothing` draws them exactly when `system.friction !== nothing`.

The geometry comes from the rotation itself: in 2D the angle of the line is the rotation
angle, and in 3D the line is the body-fixed diameter along `x`, rotated by the rotation
vector with Rodrigues' formula and then projected on the image plane.
"""
function render_frame!(path::AbstractString, s::System{D}, size::Int;
                       markers::Union{Bool,Nothing} = nothing) where {D}
    draw_markers = markers === nothing ? s.friction !== nothing : markers
    image = fill(UInt8(255), 3, size, size)
    scale = size / s.side
    order = collect(eachindex(s.positions))
    if D == 3
        sort!(order; by = i -> s.positions[i][3])
    end
    diameter_max = maximum(s.diameters)
    for i in order
        x = s.positions[i][1] * scale
        y = s.positions[i][2] * scale
        radius = 0.5 * s.diameters[i] * scale
        depth = D == 3 ? 0.7 + 0.3 * (s.positions[i][3] / s.side) : 1.0
        radius *= depth
        color = s.diameters[i] >= 0.9 * diameter_max ? LARGE_COLOR : SMALL_COLOR
        # in 3D, fog the far spheres toward white so the depth is readable
        fog = D == 3 ? 0.35 + 0.65 * (s.positions[i][3] / s.side) : 1.0
        triple = (UInt8(round(Int, fog * color[1] + (1 - fog) * 252)),
                  UInt8(round(Int, fog * color[2] + (1 - fog) * 252)),
                  UInt8(round(Int, fog * color[3] + (1 - fog) * 252)))
        # a periodic box wraps particles that cross the frame, so draw the copies too
        xs = Float64[x]
        ys = Float64[y]
        if s.boundary isa Periodic
            x - radius < 1 && push!(xs, x + size)
            x + radius > size && push!(xs, x - size)
            y - radius < 1 && push!(ys, y + size)
            y + radius > size && push!(ys, y - size)
        end
        ux, uy, visibility = draw_markers ? marker_direction(s, i) : (1.0, 0.0, 0.0)
        marker = draw_markers ?
            ntuple(_ -> UInt8(round(Int, fog * MARKER_COLOR[1] + (1 - fog) * 252)), 3) :
            triple
        thickness = max(1, round(Int, radius / 12))
        for dx in xs, dy in ys
            draw_disk!(image, dx, dy, radius, triple, size)
            draw_markers || continue
            if visibility < 1 / 6
                draw_disk!(image, dx, dy, max(1.0, 0.18 * radius), marker, size)
            else
                half = radius * min(visibility, 1.0)
                draw_segment!(image, dx - half * ux, dy - half * uy,
                              dx + half * ux, dy + half * uy, marker, thickness, size)
            end
        end
    end
    if s.boundary isa Walls
        border = (UInt8(60), UInt8(60), UInt8(60))
        draw_rectangle!(image, 1, 1, size, size, border)
    end
    open(path, "w") do io
        write(io, "P6\n", string(size), " ", string(size), "\n255\n")
        bytes = Vector{UInt8}(undef, 3 * size * size)
        k = 1
        @inbounds for row in 1:size, column in 1:size
            bytes[k] = image[1, row, column]
            bytes[k + 1] = image[2, row, column]
            bytes[k + 2] = image[3, row, column]
            k += 3
        end
        write(io, bytes)                            # row-major, red-green-blue
    end
    return nothing
end

"""
    marker_direction(system, i)

Unit image-plane direction of the diameter line drawn on particle `i`, and how much of it
the projection keeps (1 in 2D, the length of the projected unit vector in 3D). The line
is body-fixed: in 2D it turns with the rotation angle, and in 3D it is the particle's
`x` diameter rotated by the rotation vector, then projected on the image plane.
"""
function marker_direction(s::System, i::Int)
    w = s.rotations[i]
    if length(w) == 1
        angle = w[1]
        return (cos(angle), sin(angle), 1.0)
    end
    angle = sqrt(w[1]^2 + w[2]^2 + w[3]^2)
    if angle < 1e-12
        return (1.0, 0.0, 1.0)
    end
    kx, ky, kz = w[1] / angle, w[2] / angle, w[3] / angle
    c, sn = cos(angle), sin(angle)
    # Rodrigues: rotate the x axis about k by the rotation angle
    ux = c + kx * kx * (1 - c)
    uy = kz * sn + kx * ky * (1 - c)
    visibility = sqrt(ux * ux + uy * uy)
    visibility < 1e-12 && return (1.0, 0.0, 0.0)
    return (ux / visibility, uy / visibility, visibility)
end

"""
    draw_disk!(image, x, y, radius, color, size)

Fill a disk into the image; `y` counts up from the bottom.
"""
function draw_disk!(image, x::Float64, y::Float64, radius::Float64, color, size::Int)
    x_min = max(1, floor(Int, x - radius))
    x_max = min(size, ceil(Int, x + radius))
    y_min = max(1, floor(Int, y - radius))
    y_max = min(size, ceil(Int, y + radius))
    radius_squared = radius^2
    @inbounds for row in y_min:y_max, column in x_min:x_max
        dx = column - x
        dy = row - y
        if dx^2 + dy^2 <= radius_squared
            pixel_row = size - row + 1
            image[1, pixel_row, column] = color[1]
            image[2, pixel_row, column] = color[2]
            image[3, pixel_row, column] = color[3]
        end
    end
    return nothing
end

"""
    set_pixel!(image, column, row, color, size)

Set one pixel, if it lies inside the image; `row` counts up from the bottom.
"""
@inline function set_pixel!(image, column::Int, row::Int, color, size::Int)
    if 1 <= column <= size && 1 <= row <= size
        pixel_row = size - row + 1
        @inbounds image[1, pixel_row, column] = color[1]
        @inbounds image[2, pixel_row, column] = color[2]
        @inbounds image[3, pixel_row, column] = color[3]
    end
    return nothing
end

"""
    draw_segment!(image, x0, y0, x1, y1, color, thickness, size)

Draw a straight segment `thickness` pixels wide between two points, sampling along the
longer axis so the line has no gaps.
"""
function draw_segment!(image, x0::Float64, y0::Float64, x1::Float64, y1::Float64,
                       color, thickness::Int, size::Int)
    steps = max(1, ceil(Int, max(abs(x1 - x0), abs(y1 - y0))))
    half = (thickness - 1) / 2
    for k in 0:steps
        t = k / steps
        x = x0 + t * (x1 - x0)
        y = y0 + t * (y1 - y0)
        for dy in -half:half, dx in -half:half
            set_pixel!(image, round(Int, x + dx), round(Int, y + dy), color, size)
        end
    end
    return nothing
end

"""
    draw_rectangle!(image, x_min, y_min, x_max, y_max, color)

A one-pixel rectangle at the image border.
"""
function draw_rectangle!(image, x_min::Int, y_min::Int, x_max::Int, y_max::Int, color)
    for column in x_min:x_max, row in (y_min, y_max)
        pixel_row = size(image, 2) - row + 1
        image[:, pixel_row, column] .= color
    end
    for row in y_min:y_max, column in (x_min, x_max)
        pixel_row = size(image, 2) - row + 1
        image[:, pixel_row, column] .= color
    end
    return nothing
end

"""
    render_packing(path, packing; size = 640, markers = nothing)

Draw a finished packing to a PPM image `path`. The marker rule is the one of
[`render_frame!`](@ref).
"""
function render_packing(path::AbstractString, p::Packing; size::Int = 640,
                        markers::Union{Bool,Nothing} = nothing)
    render_frame!(path, p.system, size; markers = markers)
    return nothing
end
