package main

// components is filled in by components_*.go (Phase 2).
type component interface{}

var components = newRegistry[component]()
