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
