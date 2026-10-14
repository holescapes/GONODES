# Signed Distance Fields (SDF)

SDF operators describe a shape as a distance to its surface. Booleans and repeats stay exact because they combine distances, not triangles. Nothing is downloaded or installed. The family ships with GONODES.

An SDF node does not draw itself. RaymarchSDF turns the shape into a texture. WindowOUT shows that texture.

## A first patch

1. Add **SphereSDF**.
2. Add **RaymarchSDF** and connect the sphere to it.
3. Add **WindowOUT** at 512×512 with Open on, and connect RaymarchSDF to it.

## A boolean

1. Add two **SphereSDF** nodes and move one with Position X.
2. Add **SmoothUnionSDF** and connect both spheres to it.
3. Connect the union to **RaymarchSDF**, then to **WindowOUT**.

SubtractSDF cuts one shape out of another. IntersectionSDF keeps only the overlap. TwistSDF, RepeatSDF, and RoundSDF sit between a shape and the raymarch when you want to bend, tile, or soften it.

Right-click SphereSDF or RaymarchSDF and choose Help for a finished patch. An SDF that does not reach a WindowOUT does not cook.
