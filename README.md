# Floorplan.rb (Ruby DSL for 2D floorplans)

Text-first floorplans in Ruby, inspired by OpenSCAD. Write a plan in a Ruby DSL, render to SVG, and view in the browser via a built-in WEBrick server with live reload.

## Quick start

- Serve in browser (default: http://127.0.0.1:9393):

```
bin/fp serve examples/simple_room.rb
```

- Build SVG to file:

```
bin/fp build examples/simple_room.rb -o out.svg
```

## DSL sketch

```ruby
Floorplan.plan do
  units :meters
  origin :lower_left

  layer :walls
  walls thickness: 0.2.m

  start at: [0.m, 0.m]
  go :east, 4.m, id: :w1
  go :north, 3.m, id: :w2
  go :west, 4.m, id: :w3
  close_path id: :w4

  opening wall: :w1, at: 1.2.m, type: :door, width: 0.9.m, swing: :left_in
end
```

See `examples/simple_room.rb`, `examples/l_shape.rb`, and `examples/two_rooms.rb`.

## Commands

- `fp serve plan.rb [--port 9393] [--host 127.0.0.1] [--no-live]` — view in browser with live reload.
- `fp build plan.rb -o out.svg` — render to SVG.
- `fp validate plan.rb` — run validations only.
- `fp inspect plan.rb -o out.json` — dump debug geometry (stubbed).

## Notes

- Internal unit is millimeters. Helpers: `1.m`, `20.cm`, `150.mm`.
- WEBrick may require `gem install webrick` on Ruby 3+.
- Rendering draws wall polygons with thickness; openings are cut as gaps (windows show a light blue frame line). This is an MVP and will evolve.
 - Rooms: define via `polygon: [[x,y],...]` or `by_loop: [:w1,:w2,...]`. Rooms render as light fills with optional labels.
