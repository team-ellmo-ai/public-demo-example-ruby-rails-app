require "application_system_test_case"

class TasksTest < ApplicationSystemTestCase
  setup do
    @task = tasks(:one)
  end

  test "deleting a task from the list" do
    visit tasks_url

    accept_confirm do
      click_on "Delete", match: :first
    end

    assert_text "Task was successfully destroyed"
  end
end
