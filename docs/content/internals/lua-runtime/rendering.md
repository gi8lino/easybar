# Rendering

Rendering is handled in `render.lua`.

## Key design

Widgets mutate registry state.

The renderer builds tree output from registry state.

## Steps

1. build nested tree
2. attach popup nodes
3. compute interactions
4. flatten tree
5. emit JSON

## Deduplication

- last output is cached by root id
- identical trees are skipped

## Swift tree application

Swift-side application is handled in:

- `WidgetEngine`
- `WidgetStore`

Update logic:

1. remove old nodes for root
2. insert new nodes
3. rebuild index

No diffing is needed.
