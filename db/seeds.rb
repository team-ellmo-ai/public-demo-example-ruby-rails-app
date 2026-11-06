# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# One transaction: either every example task is seeded or none are.
ActiveRecord::Base.transaction do
  [
    { title: "Install Ruby on Rails", description: "Set up Ruby, Rails, and SQLite.", completed: true },
    { title: "Generate the Tasks scaffold", description: "CRUD for tasks, backed by ActiveRecord.", completed: true },
    { title: "Brand it for tryellmo.ai", description: "Give the demo app its own look and title.", completed: true },
    { title: "Try editing a task", description: "Click Edit on any row to see it in action.", completed: false }
  ].each do |attrs|
    Task.find_or_create_by!(title: attrs[:title]) do |task|
      task.description = attrs[:description]
      task.completed = attrs[:completed]
    end
  end
end
