# ---------------------------------------------------------------------------
#  Movie frames (design §11): each frame is a PPM image drawn straight from the
#  positions; ffmpeg turns the frames into the movie at the end of the run.
#  A PPM needs no library, and ffmpeg is the only external tool.
# ---------------------------------------------------------------------------

const SMALL_COLOR = (UInt8(70), UInt8(130), UInt8(180))
const LARGE_COLOR = (UInt8(235), UInt8(145), UInt8(60))

"""
    render_frame!(path, system, size)

Draw the current state as a `size` by `size` PPM image: disks (2D) or spheres seen from
above (3D, with the far particles drawn first and slightly smaller), coloured by diameter,
with a frame for walls. No axes, no labels.
"""
function render_frame!(path::AbstractString, s::System{D}, size::Int) where {D}
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
        draw_disk!(image, x, y, radius, triple, size)
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
    render_packing(path, packing; size = 640)

Draw a finished packing to a PPM image `path`.
"""
function render_packing(path::AbstractString, p::Packing; size::Int = 640)
    render_frame!(path, p.system, size)
    return nothing
end
