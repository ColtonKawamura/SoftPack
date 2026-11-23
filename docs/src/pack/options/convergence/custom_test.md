# Your own test function

*Up:* [`convergence`](index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [Any function](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#any-function).

Any function `my_test(state)` that returns true when the packing is at rest at the current box. It receives a read-only `RunState` ([fields](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#the-state-a-user-function-receives)) and is called at the end of every step. A `true` ends the current minimization, not the run, and the pressure check still follows.
