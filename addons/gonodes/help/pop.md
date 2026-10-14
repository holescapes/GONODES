# Particles (POP)

POP operators simulate particles on the GPU. Nothing is downloaded or installed. The family ships with GONODES.

A POP does not draw itself. RenderPOP turns the particles into a scene object. A camera and RenderTOP draw that object into a texture, and WindowOUT shows the texture.

## A first patch

1. Add **SourcePOP**. It emits points and keeps them alive for a few seconds.
2. Add **RenderPOP** and connect SourcePOP to it.
3. Add **CameraCOMP** and **RenderTOP**. Connect RenderPOP to the RenderTOP geometry input, and the camera to the camera input.
4. Add **WindowOUT** at 512×512 with Open on, and connect RenderTOP to it.

ForcePOP, AttractPOP, CollisionPOP, and TurbulencePOP sit between SourcePOP and RenderPOP when you want the points to move. BoidsPOP is a flock on its own and still ends at RenderPOP.

Right-click SourcePOP or RenderPOP and choose Help for a finished chain. A POP that does not reach a WindowOUT does not cook.
