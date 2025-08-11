Floorplan.plan do
  units :meters
  origin :lower_left

  layer :walls
  # Enter interior dimensions; walls expand outward from the inner face
  walls thickness: 0.2.m, ref: :inner_face

  # Interior clear size: 4.0m x 3.0m
  start at: [0.m, 0.m]
  go :east, 4.m, id: :w1
  go :north, 3.m, id: :w2
  go :west, 4.m, id: :w3
  close_path id: :w4

  # A door on the long wall, measured along the wall
  opening wall: :w1, at: 1.0.m, type: :door, width: 0.9.m, swing: :left_in

  # Room label with area will be centered automatically
  room :living, by_loop: [:w1, :w2, :w3, :w4], label: "Living"
end
