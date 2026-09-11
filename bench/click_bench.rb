# frozen_string_literal: true

require "syrma"

mode = (ARGV[0] || "each").to_sym
raise ArgumentError, "mode must be each or gesture" unless %i[each gesture].include?(mode)

%i[none deterministic].each do |text|
  count = 0
  session = Syrma::Session.new(width: 800, height: 600, text: text, event_frames: mode) do |window|
    window.draw do
      Zaniah::Div.new.flex_col.p(4).gap(2).children((0...50).map do |index|
        Zaniah::Div.new.h(8).test_id("r#{index}").on_click { count += 1 }
          .child(Zaniah::Text.new("item #{index} #{count}", size: 6))
      end)
    end
  end
  iterations = 200
  frame_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { session.window.request_frame; session.settle }
  frame_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - frame_started

  builder = Syrma::SnapshotBuilder.new
  tree_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { builder.build(session.window) }
  tree_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - tree_started

  locator = session.test_id("r0")
  tree = session.tree
  locator_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { locator.resolve(tree) }
  locator_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - locator_started

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times do |index|
    session.test_id("r#{index % 50}").click
    raise "verification failed" unless session.texts.any?
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  puts format("event_frames=%-8s text=%-13s elements=%d frame=%.2fms tree=%.2fms locator=%.3fms click+check=%.1fms/op",
              mode, text, session.tree.nodes.size, frame_elapsed / iterations * 1000,
              tree_elapsed / iterations * 1000, locator_elapsed / iterations * 1000,
              elapsed / iterations * 1000)
  session.close
end
