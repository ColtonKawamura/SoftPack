using Documenter

# Build the SoftPack documentation: `julia --project=docs docs/make.jl`
makedocs(;
    sitename = "SoftPack",
    authors = "Colton Kawamura",
    modules = Module[],
    repo = Documenter.Remotes.GitHub("ColtonKawamura", "SoftPack"),
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://coltonkawamura.github.io/SoftPack/",
        edit_link = "main",
        inventory_version = "dev",
        mathengine = Documenter.KaTeX(),
        assets = ["assets/custom.css"],
    ),
    pages = [
        "Home" => "index.md",
        "pack()" => [
            "Overview" => "pack/index.md",
            "Available options" => [
                "Overview" => "pack/options/index.md",
                "`dimension`" => "pack/options/dimension.md",
                "`particles_count`" => "pack/options/particles_count.md",
                "`particles_size_distribution`" => [
                    "Overview" => "pack/options/particles_size_distribution/index.md",
                    "`Bidisperse()`" => "pack/options/particles_size_distribution/Bidisperse.md",
                    "`UniformPolydisperse()`" => "pack/options/particles_size_distribution/UniformPolydisperse.md",
                    "`Monodisperse()`" => "pack/options/particles_size_distribution/Monodisperse.md",
                ],
                "`particles_diameters`" => "pack/options/particles_diameters.md",
                "`contact`" => [
                    "Overview" => "pack/options/contact/index.md",
                    "`Hookean()`" => "pack/options/contact/Hookean.md",
                    "`Hertzian()`" => "pack/options/contact/Hertzian.md",
                ],
                "`friction`" => [
                    "Overview" => "pack/options/friction/index.md",
                    "`CundallStrack()`" => "pack/options/friction/CundallStrack.md",
                    "`Mindlin()`" => "pack/options/friction/Mindlin.md",
                ],
                "`mass`" => [
                    "Overview" => "pack/options/mass/index.md",
                    "`EqualMass()`" => "pack/options/mass/EqualMass.md",
                    "`Density()`" => "pack/options/mass/Density.md",
                ],
                "`target`" => [
                    "Overview" => "pack/options/target/index.md",
                    "`Pressure()`" => "pack/options/target/Pressure.md",
                ],
                "`boundary`" => [
                    "Overview" => "pack/options/boundary/index.md",
                    "`Periodic()`" => "pack/options/boundary/Periodic.md",
                    "`Walls()`" => "pack/options/boundary/Walls.md",
                ],
                "`initial_state`" => [
                    "Overview" => "pack/options/initial_state/index.md",
                    "`Dilute()`" => "pack/options/initial_state/Dilute.md",
                ],
                "`protocol`" => [
                    "Overview" => "pack/options/protocol/index.md",
                    "`IsotropicCompression()`" => "pack/options/protocol/IsotropicCompression.md",
                ],
                "`convergence`" => [
                    "Overview" => "pack/options/convergence/index.md",
                    "`RelativeForce()`" => "pack/options/convergence/RelativeForce.md",
                    "`LeidenAcceleration()`" => "pack/options/convergence/LeidenAcceleration.md",
                    "`KineticEnergy()`" => "pack/options/convergence/KineticEnergy.md",
                    "`RestartTest()`" => "pack/options/convergence/RestartTest.md",
                    "Your own test function" => "pack/options/convergence/custom_test.md",
                ],
                "`pressure_tolerance`" => "pack/options/pressure_tolerance.md",
                "`steps_max`" => "pack/options/steps_max.md",
                "`failure_action`" => "pack/options/failure_action.md",
                "`restart_packing`" => "pack/options/restart_packing.md",
                "`restart_file`" => [
                    "Overview" => "pack/options/restart_file/index.md",
                    "`RestartFile()`" => "pack/options/restart_file/RestartFile.md",
                ],
                "`algorithm`" => [
                    "Overview" => "pack/options/algorithm/index.md",
                    "`FIRE()`" => "pack/options/algorithm/FIRE.md",
                    "`DampedDynamics()`" => [
                        "Overview" => "pack/options/algorithm/DampedDynamics/index.md",
                        "`damping`" => [
                            "Overview" => "pack/options/algorithm/DampedDynamics/damping/index.md",
                            "`ContactDamping()`" => "pack/options/algorithm/DampedDynamics/damping/ContactDamping.md",
                            "`ViscousRate()`" => "pack/options/algorithm/DampedDynamics/damping/ViscousRate.md",
                            "`RelativeVelocityDamping()`" => "pack/options/algorithm/DampedDynamics/damping/RelativeVelocityDamping.md",
                        ],
                        "`drag`" => [
                            "Overview" => "pack/options/algorithm/DampedDynamics/drag/index.md",
                            "`StokesDrag()`" => "pack/options/algorithm/DampedDynamics/drag/StokesDrag.md",
                        ],
                        "`integrator`" => [
                            "Overview" => "pack/options/algorithm/DampedDynamics/integrator/index.md",
                            "`:centered_velocity_verlet`" => "pack/options/algorithm/DampedDynamics/integrator/centered_velocity_verlet.md",
                            "`:lagged_velocity_verlet`" => "pack/options/algorithm/DampedDynamics/integrator/lagged_velocity_verlet.md",
                            "`:semi_implicit_euler`" => "pack/options/algorithm/DampedDynamics/integrator/semi_implicit_euler.md",
                        ],
                    ],
                ],
                "`timestep`" => [
                    "Overview" => "pack/options/timestep/index.md",
                    "`CollisionTime()`" => "pack/options/timestep/CollisionTime.md",
                ],
                "`rattlers`" => [
                    "Overview" => "pack/options/rattlers/index.md",
                    "`ContactCount()`" => "pack/options/rattlers/ContactCount.md",
                    "`TwoContact()`" => "pack/options/rattlers/TwoContact.md",
                    "`ForceFloor()`" => "pack/options/rattlers/ForceFloor.md",
                    "`Unresolved()`" => "pack/options/rattlers/Unresolved.md",
                    "Your own rule function" => "pack/options/rattlers/custom_rule.md",
                    "`find_rattlers()`" => "pack/options/rattlers/find_rattlers.md",
                ],
                "`seed`" => "pack/options/seed.md",
                "`snapshots`" => [
                    "Overview" => "pack/options/snapshots/index.md",
                    "`Snapshots()`" => "pack/options/snapshots/Snapshots.md",
                ],
                "`movie`" => [
                    "Overview" => "pack/options/movie/index.md",
                    "`Movie()`" => "pack/options/movie/Movie.md",
                ],
            ],
            "`PackParams()`" => "pack/PackParams.md",
            "Packing" => "pack/Packing.md",
        ],
        "write_packing()" => [
            "Overview" => "write_packing/index.md",
            "`path`" => "write_packing/path.md",
            "`rattlers_file`" => "write_packing/rattlers_file.md",
            "`compression`" => "write_packing/compression.md",
        ],
        "Reference" => [
            "Naming rules" => "reference/naming.md",
            "Units and length unit" => "reference/units.md",
            "Theory pages" => "reference/theory.md",
            "Notation" => "reference/notation.md",
            "References" => "reference/references.md",
        ],
    ],
)

deploydocs(;
    repo = "github.com/ColtonKawamura/SoftPack.git",
    devbranch = "main",
    versions = nothing,
    push_preview = true,
)
