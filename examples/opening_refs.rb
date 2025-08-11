Floorplan.plan do
  units :meters
  origin :lower_left

  layer :walls
  walls thickness: 0.24.m

  # 4m x 3m room
  start at: [0.m, 0.m]
  go :east, 4.m, id: :w1
  go :north, 3.m, id: :w2
  go :west, 4.m, id: :w3
  close_path id: :w4

  # Same door position measured from different references
  opening wall: :w1, at: 0.9.m, type: :door, width: 0.9.m, swing: :left_in, ref: :centerline, id: :d_center
  opening wall: :w3, at: 0.9.m, type: :door, width: 0.9.m, swing: :left_in, ref: :inner_face, id: :d_inner
  opening wall: :w2, at: 0.9.m, type: :door, width: 0.9.m, swing: :left_in, ref: :outer_face, id: :d_outer
end
