# Roadmap: other particle shapes

*Up:* [SoftPack](index.md)

!!! note "Roadmap, not designed"
    Nothing on this page is designed, and none of it is promised for a first release.
    It records what is planned and what the design keeps open, so that it can be added without changing the meaning of any call made today.
    The decision is in section 15 of the [design document](https://github.com/ColtonKawamura/SoftPack/blob/main/docs/design-references.md#15-roadmap-other-particle-shapes), and the wiki has the same page: [Roadmap](https://github.com/ColtonKawamura/SoftPack/wiki/Roadmap).

SoftPack's particles are disks in 2D and spheres in 3D, fixed by [`dimension`](pack/options/dimension.md) (see [`mass`](pack/options/mass/index.md)).

## Planned shapes

- Cylinders (3D disks): a disk with a thickness, in a 3D box.
- User-defined shapes: the user passes their own shape functions, the right-hand column of the table below.
- Spheres confined to a plane, the Leiden 2D convention, would come back as one more 2D shape with sphere mass and $\kappa = 2/5$.
  - It would be a shape, not a `Density` keyword.

## What a shape provides

A shape is more than a mass formula.
The table lists everything in the design that assumes a disk or a sphere, with what another shape would have to supply instead.

| Quantity | Disk and sphere today | Any other shape |
|:---|:---|:---|
| Size | one diameter $d_i$ | shape parameters (a cylinder: diameter and thickness) |
| Mass | $\rho\,\pi d^2/4$ or $\rho\,\pi d^3/6$ | $\rho$ times the shape's area or volume |
| Moment of inertia | the scalar $I = \kappa\,mR^2$ | in 3D an inertia tensor about the center of mass |
| Rotation state | an angle (2D) or a spin vector (3D) | an orientation and a spin vector |
| Contact | overlap $\delta = (d_i + d_j)/2 - r_{ij}$ along the line of centers | a function that returns the overlap, the contact normal and the contact point, for a pair and for a wall |
| Effective masses | $M_n$ from the masses alone, $M_t$ adds $R^2/I$ | both include rotation: each particle adds $(\mathbf r\times\hat{\mathbf e})^\top\mathbf I^{-1}(\mathbf r\times\hat{\mathbf e})$ to $1/m$, with $\mathbf r$ the vector to the contact point and $\hat{\mathbf e}$ the force direction |
| Pressure | a tangential force drops out because the normal lies along $\boldsymbol\ell^{c}$ | in general it does not drop out |
| Stored output | diameters and masses | the shape kind, its parameters and the orientations |

## Rules for the first implementation

All **SoftPack choice**, so that the planned shapes can be added later.

- Every shape-specific quantity in the table sits behind one shape interface, with the disk and the sphere as its first two members.
  - No other code writes $\pi d^2/4$, $R^2/I$ or $(d_i + d_j)/2 - r_{ij}$.
- The contact laws, friction models and dashpots read the overlap, the normal, the contact point and the effective masses from the shape's contact, not the diameters.
  - Torques are $\mathbf r\times\mathbf f$ about the contact point, which for a disk or a sphere is $R\hat{\mathbf n}$.
- Output and restart files record a shape kind beside each diameter, so a file written today still reads after more shapes exist.
- A new shape arrives as an addition, a new value or constructor with today's disk or sphere as the default, so no call written today changes meaning.

## Open questions

- The contact test and the neighbor search for non-round shapes.
- How a shape sets the length unit and the packing fraction.
- The contact laws for non-round shapes, since the Hertz law depends on the curvatures at the contact.
- The rattler counts.
