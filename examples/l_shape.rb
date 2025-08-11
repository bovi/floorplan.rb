Floorplan.plan do
  units :meters
  origin :lower_left

  layer :walls
  walls thickness: 0.2.m

  # L-shaped external walls
  start at: [0.m, 0.m]
  go :east, 5.m, id: :w1
  go :north, 3.m, id: :w2
  go :west, 2.m, id: :w3
  go :north, 2.m, id: :w4
  go :west, 3.m, id: :w5
  go :south, 5.m, id: :w6

  # Openings: a front door on w1 and a window on w3
  opening wall: :w1, at: 1.0.m, type: :door, width: 0.9.m, swing: :left_in
  opening wall: :w3, at: 0.5.m, type: :window, width: 1.2.m, sill: 0.9.m
end
