# frozen_string_literal: true

require "erb"
require "fileutils"
require "pathname"

module Syrma
  module Report
    module_function

    def generate(root: nil, output: nil)
      root = File.expand_path(root || ENV["SYRMA_ARTIFACTS"] || Syrma.configuration.artifacts_dir)
      output ||= File.join(root, "report.html")
      summaries = Dir[File.join(root, "**", "summary.md")].sort
      FileUtils.mkdir_p(File.dirname(output))
      File.write(output, html(root, summaries), encoding: "UTF-8")
      output
    end

    def html(root, summaries)
      sections = summaries.map { |path| section(root, path) }.join
      sections = "<p>No failures recorded.</p>" if sections.empty?
      <<~HTML
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Syrma test report</title>
          <style>body{font:14px system-ui;max-width:1200px;margin:auto;padding:24px;color:#18202a}section{border-top:1px solid #ccd4dd;padding:20px 0}.images{display:flex;gap:12px;overflow:auto}.images figure{margin:0}.images img{max-width:360px;border:1px solid #ccd4dd}pre{white-space:pre-wrap;background:#f4f6f8;padding:12px}</style>
        </head>
        <body><h1>Syrma test report</h1>#{sections}</body>
        </html>
      HTML
    end

    def section(root, summary_path)
      dir = File.dirname(summary_path)
      title = File.basename(dir)
      summary = ERB::Util.html_escape(File.read(summary_path, encoding: "UTF-8"))
      images = %w[expected.png actual.png diff.png screenshot.png].filter_map do |name|
        path = File.join(dir, name)
        next unless File.exist?(path)

        relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
        "<figure><figcaption>#{name}</figcaption><img src=\"#{ERB::Util.html_escape(relative)}\" alt=\"#{name}\"></figure>"
      end.join
      details = %w[tree.txt events.log].filter_map do |name|
        path = File.join(dir, name)
        next unless File.exist?(path)

        "<details><summary>#{name}</summary><pre>#{ERB::Util.html_escape(File.read(path, encoding: 'UTF-8'))}</pre></details>"
      end.join
      "<section><h2>#{ERB::Util.html_escape(title)}</h2><pre>#{summary}</pre><div class=\"images\">#{images}</div>#{details}</section>"
    end
  end
end
