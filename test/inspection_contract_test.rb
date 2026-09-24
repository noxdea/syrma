# frozen_string_literal: true

require_relative "test_helper"

class InspectionContractTest < Minitest::Test
  def test_installed_zaniah_snapshot_and_semantic_search
    button = Zaniah::Div.new
    button.define_singleton_method(:accessibility_node) do |_context|
      Zaniah::Accessibility.node(role: :button, label: "Save")
    end
    session = Syrma::Session.new(width: 200, height: 100) do |window|
      window.draw { button }
    end
    snapshot = Zaniah::Inspection.snapshot(session.driver.window)
    assert_equal session.driver.tree.frame, snapshot.frame.number
    assert_equal "Div", snapshot.root.type
    node, path = session.driver.accessibility(role: :button, label: "Save").first
    assert_equal :button, node.role
    assert_equal [], path
    assert_empty session.driver.accessibility(role: :button, label: "Missing")
  ensure
    session&.close
  end

  def test_visual_hit_search_uses_transformed_regions
    session = Syrma::Session.new(width: 100, height: 40) do |window|
      window.draw do
        Zaniah::Div.new.child(Zaniah::Div.new.w(20).h(20)
          .style(transform: Zaniah::Transform.translate(20, 0)).test_id("moved").on_click {})
      end
    end
    assert_equal "moved", session.driver.at(25, 10)&.test_id
    refute_equal "moved", session.driver.at(5, 10)&.test_id
  ensure
    session&.close
  end
end
