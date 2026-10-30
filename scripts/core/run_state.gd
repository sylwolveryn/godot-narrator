class_name RunState
extends RefCounted
## Per-run data. A fresh instance is created for every run, so nothing can leak
## from a previous run. Add per-run fields here.

var run_index: int = 0
var elapsed: float = 0.0
var end_cause: StringName = &""
## The input scheme in use for this run (an InputScheme constant); NONE until discovered.
var input_scheme: StringName = InputScheme.NONE
