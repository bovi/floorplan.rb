Floorplan.plan do
  units :meters
  origin :lower_left

  layer :walls
  walls thickness: 0.2.m

  # Outer rectangle 6m x 4m
  start at: [0.m, 0.m]
  go :east, 6.m, id: :w1
  go :north, 4.m, id: :w2
  go :west, 6.m, id: :w3
  close_path id: :w4

  # Internal partition at x=3m (vertical)
  line from: [3.m, 0.m], to: [3.m, 4.m], id: :w5, thickness: 0.15.m

  # Openings
  opening wall: :w1, at: 0.5.m, type: :door, width: 0.9.m, swing: :left_in
  opening wall: :w5, at: 1.5.m, type: :door, width: 0.8.m, swing: :left_in

  # Rooms via explicit polygons (using interior rectangles)
  room :living, label: "Living", polygon: [[0.m,0.m],[3.m,0.m],[3.m,4.m],[0.m,4.m]]
  room :kitchen, label: "Kitchen", polygon: [[3.m,0.m],[6.m,0.m],[6.m,4.m],[3.m,4.m]]
end
