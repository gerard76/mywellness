# Known Mywellness machine mappings (add your phIds here)
machines = [
  { ph_id: "4cc3ddbb-af3a-4337-8dbc-d4bfa2a7b305", name: "Hip Adduction",   muscle_group: "Legs" },
  { ph_id: "3282bd6b-ed77-4a28-919e-ef36aeb5e434", name: "Arm Curl",         muscle_group: "Arms" },
  { ph_id: "3bd74b3a-9464-4179-995a-5d5312919c07", name: "Arm Adduction",    muscle_group: "Arms" },
  { ph_id: "b0e7c45c-7f47-4eda-8e40-6394f4fb5099", name: "Arm Extension",    muscle_group: "Arms" },
  { ph_id: "5a9f6125-212d-447d-8248-341739ca77ed", name: "Pull Down",        muscle_group: "Chest & Shoulders" },
  { ph_id: "b6516942-1dc0-4c9a-afa9-65688d58159c", name: "Hip Abduction",    muscle_group: "Legs" },
  { ph_id: "0a8bf336-c82a-402c-a559-0967d4990aab", name: "Low Row",          muscle_group: "Back" },
  { ph_id: "5ad90dc8-a6fa-4393-98d3-31f904178ac7", name: "Shoulder Press",   muscle_group: "Chest & Shoulders" },
  { ph_id: "8c5dd2b0-ec68-499f-8748-7c551d1cacc7", name: "Pectoral",         muscle_group: "Chest & Shoulders" },
  { ph_id: "2538481e-06d6-44a3-b40f-474a8df82e98", name: "Crunch",           muscle_group: "Core" },
  { ph_id: "30e248ed-7a85-47bb-9718-465f417be50f", name: "Leg Extension",    muscle_group: "Legs" },
  { ph_id: "34ca4f3b-50af-471b-a93f-55b04c5a0e57", name: "Leg Press",        muscle_group: "Legs" },
  { ph_id: "da02c569-a241-4c7e-8eec-b0bde62bc38c", name: "Leg Curl",         muscle_group: "Legs" },
  { ph_id: "db6e8ce7-7d12-40a9-8f5f-e09dceaab9ea", name: "Lower Back",       muscle_group: "Back" },
]

machines.each do |attrs|
  Machine.find_or_create_by(ph_id: attrs[:ph_id]) do |m|
    m.name         = attrs[:name]
    m.muscle_group = attrs[:muscle_group]
  end
end

puts "Seeded #{machines.size} machines."

Setting.find_or_create_by(key: "mywellness_club_slug") { |s| s.value = "vouershof" }
puts "Seeded club_slug: vouershof"